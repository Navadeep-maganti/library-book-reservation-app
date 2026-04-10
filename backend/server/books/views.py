from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db import transaction
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal
import re
from urllib.error import URLError
from urllib.request import Request, urlopen
from .models import (
    Book, IssuedBook, BookRenewal, BorrowHistory, BookReservation,
    Fine, FinePayment, Notification, Announcement, LibrarySettings, PushDevice
)
from .notification_service import create_notification, sync_user_notifications
from .serializers import (
    BookSerializer, BookDetailSerializer, IssuedBookSerializer, BookRenewalSerializer,
    BorrowHistorySerializer, BookReservationSerializer, FineSerializer, FinePaymentSerializer,
    NotificationSerializer, AnnouncementSerializer, LibrarySettingsSerializer,
    DashboardSummarySerializer
)

RESERVATION_HOLD_MINUTES = 30
MAX_DAILY_RESERVATION_ATTEMPTS = 2
MAX_ACTIVE_STUDENT_ITEMS = 3


def _sum_amounts(values):
    return sum(values, Decimal("0.00"))


def _resolve_pdf_url(url):
    if not url:
        return None
    if url.lower().endswith(".pdf"):
        return url

    req = Request(
        url,
        headers={'User-Agent': 'library-app-reader/1.0'},
    )
    with urlopen(req, timeout=15) as response:
        html = response.read().decode('utf-8', errors='replace')
        base_url = response.geturl()

    match = re.search(r'https://[^"\']+\.pdf', html, re.IGNORECASE)
    if match:
        return match.group(0)

    match = re.search(r'["\']([^"\']+\.pdf)["\']', html, re.IGNORECASE)
    if match:
        candidate = match.group(1)
        if candidate.startswith("http://") or candidate.startswith("https://"):
            return candidate
        if candidate.startswith("/"):
            from urllib.parse import urljoin
            return urljoin(base_url, candidate)

    return None


def _clean_reader_text(raw_text):
    text = raw_text.replace("\ufeff", "")
    text = text.replace("ï»¿", "")
    text = text.replace("â\x80\x9c", '"').replace("â\x80\x9d", '"')
    text = text.replace("â\x80\x98", "'").replace("â\x80\x99", "'")
    text = text.replace("â\x80\x94", "-").replace("â\x80\x93", "-")
    text = text.replace("â€¦", "...")
    text = text.replace("Â", "")

    start_markers = [
        "*** START OF THE PROJECT GUTENBERG EBOOK",
        "*** START OF THIS PROJECT GUTENBERG EBOOK",
    ]
    end_markers = [
        "*** END OF THE PROJECT GUTENBERG EBOOK",
        "*** END OF THIS PROJECT GUTENBERG EBOOK",
    ]

    upper_text = text.upper()
    start_index = 0
    for marker in start_markers:
        idx = upper_text.find(marker)
        if idx != -1:
            next_newline = text.find("\n", idx)
            start_index = next_newline + 1 if next_newline != -1 else idx
            break

    end_index = len(text)
    for marker in end_markers:
        idx = upper_text.find(marker)
        if idx != -1:
            end_index = idx
            break

    text = text[start_index:end_index].strip()
    lines = [line.strip() for line in text.splitlines()]
    filtered_lines = []
    skipped_preface = 0
    for line in lines:
        if not line:
            filtered_lines.append("")
            continue
        if skipped_preface < 8 and (
            line.startswith("Title:")
            or line.startswith("Author:")
            or line.startswith("Release date:")
            or line.startswith("Language:")
            or line.startswith("Produced by:")
            or "PROJECT GUTENBERG" in line.upper()
        ):
            skipped_preface += 1
            continue
        filtered_lines.append(line)

    cleaned = "\n".join(filtered_lines)
    while "\n\n\n" in cleaned:
        cleaned = cleaned.replace("\n\n\n", "\n\n")
    return cleaned.strip()


def _reservation_attempts_on_day(student, book, *, target_date):
    return BookReservation.objects.filter(
        student=student,
        book=book,
        reserved_date__date=target_date,
    ).count()


def _reservation_attempts_today(student, book, reference_time=None):
    reference_time = reference_time or timezone.now()
    target_date = timezone.localdate(reference_time)
    return _reservation_attempts_on_day(student, book, target_date=target_date)


def _reservation_attempts_remaining(student, book, reference_time=None):
    attempts = _reservation_attempts_today(
        student,
        book,
        reference_time=reference_time,
    )
    return max(0, MAX_DAILY_RESERVATION_ATTEMPTS - attempts)


def _reservation_limit_message(book_title):
    return (
        f'You have already used both reservation attempts for "{book_title}" today. '
        'Please try again tomorrow.'
    )


def _active_student_item_limit_message(*, total_active, max_allowed):
    return (
        f"You already have {total_active} active item(s) "
        f"(issued books + reservations). The maximum allowed is {max_allowed}. "
        "Return or cancel one item before making another reservation."
    )


def _active_student_item_limit(student):
    issued_count = IssuedBook.objects.filter(
        student=student,
        is_returned=False,
    ).count()
    reservation_count = BookReservation.objects.filter(
        student=student,
        status__in=["pending", "notified"],
    ).count()
    total_active = issued_count + reservation_count
    can_reserve_more = total_active < MAX_ACTIVE_STUDENT_ITEMS
    return {
        "issued_count": issued_count,
        "reservation_count": reservation_count,
        "total_active": total_active,
        "max_allowed": MAX_ACTIVE_STUDENT_ITEMS,
        "remaining_slots": max(0, MAX_ACTIVE_STUDENT_ITEMS - total_active),
        "can_reserve_more": can_reserve_more,
        "message": None if can_reserve_more else _active_student_item_limit_message(
            total_active=total_active,
            max_allowed=MAX_ACTIVE_STUDENT_ITEMS,
        ),
    }


def _calculate_overdue_days(issued, reference_time=None):
    reference_time = reference_time or timezone.now()
    due_local_date = timezone.localtime(issued.due_date).date()
    reference_local_date = timezone.localtime(reference_time).date()
    return max(0, (reference_local_date - due_local_date).days)


def _upsert_overdue_fine(*, student, issued, settings, reference_time=None):
    days_overdue = _calculate_overdue_days(issued, reference_time=reference_time)
    existing_fines = list(
        Fine.objects.filter(
            student=student,
            issued_book=issued,
            fine_type='overdue',
        ).prefetch_related('payments').order_by('issue_date', 'id')
    )
    overdue_fine = existing_fines[0] if existing_fines else None

    if days_overdue <= 0:
        return None

    fine_amount = settings.overdue_fine_per_day * days_overdue
    description = f'Overdue by {days_overdue} day(s)'

    if overdue_fine is None:
        return Fine.objects.create(
            student=student,
            issued_book=issued,
            fine_type='overdue',
            amount=fine_amount,
            description=description,
        )

    total_paid = _sum_amounts(payment.amount_paid for payment in overdue_fine.payments.all())
    overdue_fine.amount = fine_amount
    overdue_fine.description = description
    overdue_fine.is_paid = total_paid >= fine_amount
    overdue_fine.paid_date = timezone.now() if overdue_fine.is_paid else None
    overdue_fine.save(update_fields=['amount', 'description', 'is_paid', 'paid_date'])
    return overdue_fine


def _sync_overdue_fines(student, reference_time=None):
    settings = LibrarySettings.objects.first() or LibrarySettings()
    active_issues = IssuedBook.objects.filter(
        student=student,
        is_returned=False,
    ).select_related('book')

    synced_fines = []
    for issued in active_issues:
        overdue_fine = _upsert_overdue_fine(
            student=student,
            issued=issued,
            settings=settings,
            reference_time=reference_time,
        )
        if overdue_fine is not None:
            synced_fines.append(overdue_fine)
    return synced_fines


def _reorder_queue_positions(book):
    active = BookReservation.objects.filter(
        book=book,
        status__in=['pending', 'notified']
    ).order_by('reserved_date', 'id')
    for idx, reservation in enumerate(active, start=1):
        if reservation.queue_position != idx:
            reservation.queue_position = idx
            reservation.save(update_fields=['queue_position'])


def _expire_notified_holds(book=None):
    now = timezone.now()
    queryset = BookReservation.objects.filter(
        status='notified',
        expected_available_date__isnull=False,
        expected_available_date__lte=now
    ).select_related('book')
    if book is not None:
        queryset = queryset.filter(book=book)

    touched_books = {}
    for reservation in queryset:
        current_book = reservation.book
        current_book.available_copies = min(
            current_book.total_copies,
            current_book.available_copies + 1
        )
        current_book.save(update_fields=['available_copies'])
        reservation.status = 'expired'
        reservation.save(update_fields=['status'])
        attempts_today = _reservation_attempts_on_day(
            reservation.student,
            current_book,
            target_date=timezone.localdate(reservation.reserved_date),
        )
        attempts_remaining = max(0, MAX_DAILY_RESERVATION_ATTEMPTS - attempts_today)
        if attempts_remaining > 0:
            expiry_message = (
                f'Your 30-minute reservation window for "{current_book.title}" expired. '
                f'You have {attempts_remaining} reservation attempt(s) left today.'
            )
        else:
            expiry_message = (
                f'Your 30-minute reservation window for "{current_book.title}" expired. '
                'You have used both reservation attempts for this book today and '
                'can try again tomorrow.'
            )
        create_notification(
            student=reservation.student,
            notification_type='system',
            title=f'Reservation Expired: {current_book.title}',
            message=expiry_message,
            related_book=current_book,
            dedupe_key=f'reservation:{reservation.id}:expired',
        )
        touched_books[current_book.id] = current_book

    for touched in touched_books.values():
        _reorder_queue_positions(touched)


def _promote_pending_reservations(book):
    now = timezone.now()
    promoted_any = False

    while book.available_copies > 0:
        next_reservation = BookReservation.objects.filter(
            book=book,
            status='pending'
        ).order_by('queue_position', 'reserved_date').first()
        if not next_reservation:
            break

        deadline = now + timedelta(minutes=RESERVATION_HOLD_MINUTES)
        next_reservation.status = 'notified'
        next_reservation.expected_available_date = deadline
        next_reservation.save(update_fields=['status', 'expected_available_date'])

        book.available_copies -= 1
        book.save(update_fields=['available_copies'])
        promoted_any = True

        create_notification(
            student=next_reservation.student,
            notification_type='reservation_ready',
            title=f'Book Ready for Pickup: {book.title}',
            message=(
                f'"{book.title}" is now reserved for you. '
                f'Pick it up within {RESERVATION_HOLD_MINUTES} minutes.'
            ),
            related_book=book,
            dedupe_key=f'reservation:{next_reservation.id}:ready',
        )

    if promoted_any:
        _reorder_queue_positions(book)


def _sync_book_reservations(book):
    _expire_notified_holds(book=book)
    book.refresh_from_db(fields=['available_copies', 'total_copies'])
    _promote_pending_reservations(book)
    _reorder_queue_positions(book)


def _run_reservation_maintenance():
    _expire_notified_holds()
    book_ids = BookReservation.objects.filter(status='pending').values_list('book_id', flat=True).distinct()
    for book in Book.objects.filter(id__in=book_ids, available_copies__gt=0):
        _promote_pending_reservations(book)
        _reorder_queue_positions(book)


class BookViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Book.objects.none()
    serializer_class = BookSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        _run_reservation_maintenance()
        return Book.objects.all()

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return BookDetailSerializer
        return BookSerializer

    @action(detail=True, methods=['get'])
    def availability(self, request, pk=None):
        _run_reservation_maintenance()
        book = self.get_object()
        reservations = book.reservations.filter(status__in=['pending', 'notified']).count()

        # Get next available date estimation
        next_available = None
        latest_issue = book.issued_records.filter(is_returned=False).order_by('due_date').first()
        if latest_issue:
            next_available = latest_issue.due_date.isoformat()

        return Response({
            'available_copies': book.available_copies,
            'total_copies': book.total_copies,
            'waitlist_count': reservations,
            'next_available_date': next_available
        })

    @action(detail=True, methods=['get'], url_path='digital-access')
    def digital_access(self, request, pk=None):
        book = self.get_object()
        if not book.has_digital_copy:
            return Response(
                {'error': 'No digital copy is available for this title.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        access_url = None
        source = None
        if book.digital_external_url:
            try:
                access_url = _resolve_pdf_url(book.digital_external_url)
            except URLError:
                access_url = None
            source = 'external'
        elif book.digital_file:
            access_url = request.build_absolute_uri(book.digital_file.url)
            source = 'uploaded'

        if not access_url:
            return Response(
                {'error': 'A PDF version is not available for this title right now.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response({
            'book_id': book.id,
            'title': book.title,
            'has_digital_copy': True,
            'format': 'pdf',
            'can_download': book.allow_digital_download,
            'source': source,
            'access_url': access_url,
            'read_content_url': None,
        })

    @action(detail=True, methods=['get'], url_path='read-content')
    def read_content(self, request, pk=None):
        book = self.get_object()
        if not book.digital_read_url:
            return Response(
                {'error': 'No in-app reading source is available for this title.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            req = Request(
                book.digital_read_url,
                headers={'User-Agent': 'library-app-reader/1.0'},
            )
            with urlopen(req, timeout=15) as response:
                raw = response.read().decode('utf-8', errors='replace')
        except URLError:
            return Response(
                {'error': 'Could not load the reading content right now.'},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        cleaned = _clean_reader_text(raw)
        return Response({
            'book_id': book.id,
            'title': book.title,
            'author': book.author,
            'content': cleaned,
            'source_url': book.digital_read_url,
        })

    @action(detail=False, methods=['get'])
    def search(self, request):
        _run_reservation_maintenance()
        title = request.query_params.get('title', '')
        author = request.query_params.get('author', '')
        isbn = request.query_params.get('isbn', '')
        category = request.query_params.get('category', '')
        available_only = request.query_params.get('available_only', 'false').lower() == 'true'

        queryset = Book.objects.all()

        if title:
            queryset = queryset.filter(title__icontains=title)
        if author:
            queryset = queryset.filter(author__icontains=author)
        if isbn:
            queryset = queryset.filter(isbn__icontains=isbn)
        if category:
            queryset = queryset.filter(category__icontains=category)
        if available_only:
            queryset = queryset.filter(available_copies__gt=0)

        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)


class IssuedBookViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = IssuedBookSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        _sync_overdue_fines(self.request.user)
        return IssuedBook.objects.filter(student=self.request.user)

    @action(detail=False, methods=['get'])
    def my_books(self, request):
        """Get currently borrowed books"""
        _run_reservation_maintenance()
        _sync_overdue_fines(request.user)
        issued = IssuedBook.objects.filter(student=request.user, is_returned=False)
        serializer = self.get_serializer(issued, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def renew(self, request, pk=None):
        """Renew a borrowed book"""
        return Response({'error': 'Book renewal is disabled'}, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['post'])
    def issue(self, request):
        """Issue (borrow) a book"""
        _run_reservation_maintenance()
        book_id = request.data.get('book_id')

        with transaction.atomic():
            try:
                book = Book.objects.select_for_update().get(id=book_id)
            except Book.DoesNotExist:
                return Response({'error': 'Book not found'}, status=status.HTTP_404_NOT_FOUND)

            now = timezone.now()
            held_reservation = BookReservation.objects.select_for_update().filter(
                student=request.user,
                book=book,
                status='notified',
                expected_available_date__gt=now
            ).order_by('reserved_date').first()

            # Check book availability (unless already held for this student)
            if book.available_copies <= 0 and not held_reservation:
                return Response({'error': 'Book not available'}, status=status.HTTP_400_BAD_REQUEST)

            # Check max books per student
            settings = LibrarySettings.objects.first() or LibrarySettings()
            active_issues = IssuedBook.objects.filter(student=request.user, is_returned=False)
            if active_issues.count() >= settings.max_books_per_student:
                return Response({'error': f'Cannot issue more than {settings.max_books_per_student} books'},
                              status=status.HTTP_400_BAD_REQUEST)

            # Check outstanding fines
            _sync_overdue_fines(request.user, reference_time=now)
            outstanding_fines = Fine.objects.filter(student=request.user, is_paid=False)
            if outstanding_fines.exists():
                return Response({'error': 'Cannot issue books with outstanding fines'},
                              status=status.HTTP_400_BAD_REQUEST)

            # Create issued record
            due_date = now + timedelta(days=settings.borrow_days)
            issued = IssuedBook.objects.create(
                student=request.user,
                book=book,
                due_date=due_date,
                max_renewals=settings.max_renewals
            )

            if held_reservation:
                held_reservation.status = 'issued'
                held_reservation.save(update_fields=['status'])
                _reorder_queue_positions(book)
            else:
                book.available_copies -= 1
                book.save(update_fields=['available_copies'])

        # Create notification
        create_notification(
            student=request.user,
            notification_type='book_issued',
            title=f'Book Issued: {book.title}',
            message=f'You have issued "{book.title}" by {book.author}. Due date: {due_date.strftime("%d %b %Y")}',
            related_book=book,
            related_issue=issued,
            dedupe_key=f'issued:{issued.id}:created',
        )

        serializer = self.get_serializer(issued)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def return_book(self, request, pk=None):
        """Return a borrowed book"""
        _run_reservation_maintenance()
        issued = self.get_object()
        condition = request.data.get('condition', 'good')

        with transaction.atomic():
            issued = IssuedBook.objects.select_for_update().select_related('book').get(id=issued.id, student=request.user)

            if issued.is_returned:
                return Response({'error': 'Book already returned'}, status=status.HTTP_400_BAD_REQUEST)

            settings = LibrarySettings.objects.first() or LibrarySettings()
            overdue_fine = _upsert_overdue_fine(
                student=request.user,
                issued=issued,
                settings=settings,
                reference_time=timezone.now(),
            )

            if overdue_fine is not None:
                create_notification(
                    student=request.user,
                    notification_type='fine_alert',
                    title=f'Overdue Fine Added: {issued.book.title}',
                    message=(
                        f'An overdue fine of Rs {overdue_fine.amount} was added for '
                        f'"{issued.book.title}".'
                    ),
                    related_book=issued.book,
                    related_issue=issued,
                    dedupe_key=f'fine:{overdue_fine.id}:created',
                )

            if condition == 'damaged':
                damage_fine = Fine.objects.create(
                    student=request.user,
                    issued_book=issued,
                    fine_type='damage',
                    amount=200,
                    description='Book returned with damage'
                )
                create_notification(
                    student=request.user,
                    notification_type='fine_alert',
                    title=f'Damage Fine Added: {issued.book.title}',
                    message='A damage fine of Rs 200 was added to your account.',
                    related_book=issued.book,
                    related_issue=issued,
                    dedupe_key=f'fine:{damage_fine.id}:created',
                )
            elif condition == 'lost':
                lost_fine = Fine.objects.create(
                    student=request.user,
                    issued_book=issued,
                    fine_type='lost',
                    amount=500,
                    description='Book reported as lost'
                )
                create_notification(
                    student=request.user,
                    notification_type='fine_alert',
                    title=f'Lost Book Fine Added: {issued.book.title}',
                    message='A lost-book fine of Rs 500 was added to your account.',
                    related_book=issued.book,
                    related_issue=issued,
                    dedupe_key=f'fine:{lost_fine.id}:created',
                )

            # Update issued record
            issued.is_returned = True
            issued.return_date = timezone.now()
            issued.save(update_fields=['is_returned', 'return_date'])

            # Update book availability
            issued.book.available_copies = min(issued.book.total_copies, issued.book.available_copies + 1)
            issued.book.save(update_fields=['available_copies'])
            _sync_book_reservations(issued.book)

        create_notification(
            student=request.user,
            notification_type='book_returned',
            title=f'Book Returned: {issued.book.title}',
            message=f'Your return for "{issued.book.title}" was recorded successfully.',
            related_book=issued.book,
            related_issue=issued,
            dedupe_key=f'issued:{issued.id}:returned',
        )

        serializer = self.get_serializer(issued)
        return Response(serializer.data)


class BorrowHistoryViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = BorrowHistorySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = BorrowHistory.objects.filter(student=self.request.user)
        status_filter = self.request.query_params.get('status', None)

        return queryset

    @action(detail=False, methods=['get'])
    def my_history(self, request):
        """Get user's borrow history"""
        _run_reservation_maintenance()
        active_issues = IssuedBook.objects.filter(
            student=request.user,
            is_returned=False,
        ).select_related('book')
        returned_issues = IssuedBook.objects.filter(
            student=request.user,
            is_returned=True,
        ).select_related('book')
        returned_history = BorrowHistory.objects.filter(
            student=request.user,
        ).select_related('book')

        active_items = [
            {
                'id': f'issued-{record.id}',
                'student': request.user.id,
                'book': record.book.id,
                'book_title': record.book.title,
                'book_author': record.book.author,
                'issue_date': record.issue_date,
                'return_date': None,
                'duration_days': max(0, (timezone.now() - record.issue_date).days),
                'status': 'Active',
                '_sort_at': record.issue_date,
            }
            for record in active_issues
        ]
        returned_items = [
            {
                'id': f'history-{record.id}',
                'student': request.user.id,
                'book': record.book.id,
                'book_title': record.book.title,
                'book_author': record.book.author,
                'issue_date': record.issue_date,
                'return_date': record.return_date,
                'duration_days': record.duration_days,
                'status': 'Returned',
                '_sort_at': record.return_date,
            }
            for record in returned_history
        ]
        history_keys = {
            (record.book_id, record.issue_date)
            for record in returned_history
        }
        returned_fallback_items = [
            {
                'id': f'returned-issued-{record.id}',
                'student': request.user.id,
                'book': record.book.id,
                'book_title': record.book.title,
                'book_author': record.book.author,
                'issue_date': record.issue_date,
                'return_date': record.return_date,
                'duration_days': (
                    max(0, ((record.return_date or timezone.now()) - record.issue_date).days)
                ),
                'status': 'Returned',
                '_sort_at': record.return_date or record.issue_date,
            }
            for record in returned_issues
            if (record.book_id, record.issue_date) not in history_keys
        ]

        history = sorted(
            [*active_items, *returned_items, *returned_fallback_items],
            key=lambda item: item['_sort_at'] or item['issue_date'],
            reverse=True,
        )
        for item in history:
            item.pop('_sort_at', None)
        return Response(history)


class BookReservationViewSet(viewsets.ModelViewSet):
    serializer_class = BookReservationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        _run_reservation_maintenance()
        return BookReservation.objects.filter(student=self.request.user)

    @action(detail=False, methods=['post'])
    def reserve(self, request):
        """Add book to waiting list/reservation"""
        _run_reservation_maintenance()
        book_id = request.data.get('book_id')

        with transaction.atomic():
            try:
                book = Book.objects.select_for_update().get(id=book_id)
            except Book.DoesNotExist:
                return Response({'error': 'Book not found'}, status=status.HTTP_404_NOT_FOUND)

            # Check if already reserved
            existing = BookReservation.objects.select_for_update().filter(
                student=request.user,
                book=book,
                status__in=['pending', 'notified']
            )
            if existing.exists():
                return Response({'error': 'Already reserved this book'}, status=status.HTTP_400_BAD_REQUEST)

            attempts_today = _reservation_attempts_today(
                request.user,
                book,
            )
            if attempts_today >= MAX_DAILY_RESERVATION_ATTEMPTS:
                create_notification(
                    student=request.user,
                    notification_type='system',
                    title=f'Reservation Limit Reached: {book.title}',
                    message=_reservation_limit_message(book.title),
                    related_book=book,
                    dedupe_key=(
                        f'reservation-limit:{request.user.id}:{book.id}:'
                        f'{timezone.localdate().isoformat()}'
                    ),
                )
                return Response(
                    {'error': _reservation_limit_message(book.title)},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            active_item_limit = _active_student_item_limit(request.user)
            if not active_item_limit["can_reserve_more"]:
                return Response(
                    {"error": active_item_limit["message"]},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Get queue position
            queue_position = BookReservation.objects.filter(
                book=book,
                status__in=['pending', 'notified']
            ).count() + 1

            status_value = 'pending'
            expected_available_date = None
            if book.available_copies > 0:
                status_value = 'notified'
                expected_available_date = timezone.now() + timedelta(minutes=RESERVATION_HOLD_MINUTES)
                book.available_copies -= 1
                book.save(update_fields=['available_copies'])

            reservation = BookReservation.objects.create(
                student=request.user,
                book=book,
                queue_position=queue_position,
                status=status_value,
                expected_available_date=expected_available_date
            )
            _reorder_queue_positions(book)

        if status_value == 'notified':
            create_notification(
                student=request.user,
                notification_type='reservation_ready',
                title=f'Book Ready for Pickup: {book.title}',
                message=(
                    f'"{book.title}" is reserved for you for '
                    f'{RESERVATION_HOLD_MINUTES} minutes.'
                ),
                related_book=book,
                dedupe_key=f'reservation:{reservation.id}:ready',
            )
        else:
            attempts_remaining = _reservation_attempts_remaining(
                request.user,
                book,
            )
            create_notification(
                student=request.user,
                notification_type='waiting_list',
                title=f'Added to Waiting List: {book.title}',
                message=(
                    f'You are at position {queue_position} in the waiting list for '
                    f'"{book.title}". Reservation attempts left today: '
                    f'{attempts_remaining}.'
                ),
                related_book=book,
                dedupe_key=f'reservation:{reservation.id}:queued',
            )

        serializer = self.get_serializer(reservation)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        """Cancel a reservation"""
        _run_reservation_maintenance()
        with transaction.atomic():
            reservation = BookReservation.objects.select_for_update().select_related('book').get(
                id=pk,
                student=request.user
            )
            if reservation.status not in ['pending', 'notified']:
                return Response({'error': 'Reservation cannot be cancelled'}, status=status.HTTP_400_BAD_REQUEST)
            was_notified = reservation.status == 'notified'
            reservation.status = 'cancelled'
            reservation.save(update_fields=['status'])
            if was_notified:
                reservation.book.available_copies = min(
                    reservation.book.total_copies,
                    reservation.book.available_copies + 1
                )
                reservation.book.save(update_fields=['available_copies'])
                _sync_book_reservations(reservation.book)
            else:
                _reorder_queue_positions(reservation.book)

        return Response({'message': 'Reservation cancelled'})


class FineViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = FineSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        _sync_overdue_fines(self.request.user)
        return Fine.objects.filter(student=self.request.user)

    @action(detail=False, methods=['get'])
    def outstanding(self, request):
        """Get outstanding fines"""
        _sync_overdue_fines(request.user)
        fines = Fine.objects.filter(student=request.user, is_paid=False)
        serializer = self.get_serializer(fines, many=True)
        total = _sum_amounts(f.amount for f in fines)
        return Response({
            'count': fines.count(),
            'total_amount': float(total),
            'fines': serializer.data
        })

    @action(detail=False, methods=['get'])
    def summary(self, request):
        """Get fine summary"""
        _sync_overdue_fines(request.user)
        fines = Fine.objects.filter(student=request.user)
        unpaid = fines.filter(is_paid=False)

        return Response({
            'total_outstanding': float(_sum_amounts(f.amount for f in unpaid)),
            'total_paid': float(_sum_amounts(f.amount for f in fines.filter(is_paid=True))),
            'num_unpaid_fines': unpaid.count(),
            'num_total_fines': fines.count()
        })

    @action(detail=True, methods=['post'])
    def pay(self, request, pk=None):
        """Pay a fine"""
        _sync_overdue_fines(request.user)
        fine = self.get_object()

        if fine.is_paid:
            return Response({'error': 'Fine already paid'}, status=status.HTTP_400_BAD_REQUEST)

        amount_paid = request.data.get('amount_paid')
        payment_method = request.data.get('payment_method', 'cash')
        transaction_id = request.data.get('transaction_id', None)

        if not amount_paid or float(amount_paid) <= 0:
            return Response({'error': 'Invalid amount'}, status=status.HTTP_400_BAD_REQUEST)

        FinePayment.objects.create(
            fine=fine,
            amount_paid=amount_paid,
            payment_method=payment_method,
            transaction_id=transaction_id
        )

        # Check if fully paid
        total_paid = _sum_amounts(p.amount_paid for p in fine.payments.all())
        if total_paid >= fine.amount:
            fine.is_paid = True
            fine.paid_date = timezone.now()
            fine.save(update_fields=['is_paid', 'paid_date'])

        serializer = self.get_serializer(fine)
        return Response(serializer.data)


class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        _sync_overdue_fines(self.request.user)
        sync_user_notifications(self.request.user)
        return Notification.objects.filter(student=self.request.user).select_related(
            'related_book',
            'related_issue',
        )

    @action(detail=False, methods=['get'])
    def unread_count(self, request):
        """Get unread notification count"""
        _sync_overdue_fines(request.user)
        sync_user_notifications(request.user)
        count = Notification.objects.filter(student=request.user, is_read=False).count()
        return Response({'unread_count': count})

    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        """Mark all notifications as read"""
        now = timezone.now()
        updated = Notification.objects.filter(
            student=request.user,
            is_read=False,
        ).update(is_read=True, read_at=now)
        return Response({'marked_count': updated})

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        """Mark notification as read"""
        notification = self.get_object()
        notification.is_read = True
        notification.read_at = timezone.now()
        notification.save()

        serializer = self.get_serializer(notification)
        return Response(serializer.data)


class PushDeviceViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    def create(self, request):
        token = str(request.data.get('token', '')).strip()
        platform = str(request.data.get('platform', '')).strip().lower()

        if not token:
            return Response({'error': 'Token is required'}, status=status.HTTP_400_BAD_REQUEST)
        if platform not in ['android', 'ios']:
            return Response({'error': 'Platform must be android or ios'}, status=status.HTTP_400_BAD_REQUEST)

        existing = PushDevice.objects.filter(token=token).first()
        if existing is not None and existing.student_id != request.user.id:
            existing.student = request.user

        device, _ = PushDevice.objects.update_or_create(
            token=token,
            defaults={
                'student': request.user,
                'platform': platform,
                'is_active': True,
            }
        )

        return Response({
            'id': device.id,
            'platform': device.platform,
            'is_active': device.is_active,
        }, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'])
    def unregister(self, request):
        token = str(request.data.get('token', '')).strip()
        if not token:
            return Response({'error': 'Token is required'}, status=status.HTTP_400_BAD_REQUEST)

        updated = PushDevice.objects.filter(
            student=request.user,
            token=token,
            is_active=True,
        ).update(is_active=False)

        return Response({'updated_count': updated}, status=status.HTTP_200_OK)


class AnnouncementViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = AnnouncementSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Announcement.objects.filter(is_active=True)


class DueAlertsViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['get'])
    def upcoming(self, request):
        """Get due alerts"""
        _sync_overdue_fines(request.user)
        days = int(request.query_params.get('days', 7))
        today = timezone.now()
        week_end = today + timedelta(days=days)

        due_today = IssuedBook.objects.filter(
            student=request.user,
            is_returned=False,
            due_date__date=today.date()
        )

        due_this_period = IssuedBook.objects.filter(
            student=request.user,
            is_returned=False,
            due_date__gte=today,
            due_date__lte=week_end
        )

        overdue = IssuedBook.objects.filter(
            student=request.user,
            is_returned=False,
            due_date__lt=today
        )

        return Response({
            'due_today': IssuedBookSerializer(due_today, many=True).data,
            'due_this_week': IssuedBookSerializer(due_this_period, many=True).data,
            'overdue': IssuedBookSerializer(overdue, many=True).data,
            'summary': {
                'num_due_today': due_today.count(),
                'num_due_soon': due_this_period.count(),
                'num_overdue': overdue.count()
            }
        })


class DashboardViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['get'])
    def summary(self, request):
        """Get dashboard summary"""
        _run_reservation_maintenance()
        _sync_overdue_fines(request.user)
        today = timezone.now()
        week_end = today + timedelta(days=7)

        current_books = IssuedBook.objects.filter(student=request.user, is_returned=False)
        due_soon = IssuedBook.objects.filter(
            student=request.user,
            is_returned=False,
            due_date__gte=today,
            due_date__lte=week_end
        )
        overdue = IssuedBook.objects.filter(
            student=request.user,
            is_returned=False,
            due_date__lt=today
        )
        outstanding_fines = Fine.objects.filter(student=request.user, is_paid=False)
        reservations = BookReservation.objects.filter(
            student=request.user,
            status__in=['pending', 'notified']
        )
        active_item_limit = _active_student_item_limit(request.user)
        announcements = Announcement.objects.filter(is_active=True)[:5]

        return Response({
            'currently_borrowed': {
                'count': current_books.count(),
                'books': IssuedBookSerializer(current_books, many=True).data
            },
            'due_this_week': {
                'count': due_soon.count(),
                'books': IssuedBookSerializer(due_soon, many=True).data
            },
            'overdue': {
                'count': overdue.count(),
                'books': IssuedBookSerializer(overdue, many=True).data
            },
            'outstanding_fines': {
                'count': outstanding_fines.count(),
                'total_amount': float(_sum_amounts(f.amount for f in outstanding_fines))
            },
            'pending_reservations': {
                'count': reservations.count()
            },
            'active_item_limit': active_item_limit,
            'announcements': AnnouncementSerializer(announcements, many=True).data
        })
