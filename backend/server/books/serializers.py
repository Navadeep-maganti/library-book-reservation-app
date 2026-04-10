from rest_framework import serializers
from .models import (
    Book, IssuedBook, BookRenewal, BorrowHistory, BookReservation,
    Fine, FinePayment, Notification, Announcement, LibrarySettings, PushDevice
)
from django.utils import timezone
from datetime import timedelta


class BookSerializer(serializers.ModelSerializer):
    available_count = serializers.SerializerMethodField()
    has_digital_copy = serializers.SerializerMethodField()
    digital_access_url = serializers.SerializerMethodField()

    class Meta:
        model = Book
        fields = ['id', 'title', 'author', 'isbn', 'category', 'shelf', 'description',
                  'total_copies', 'available_copies', 'published_year', 'available_count',
                  'has_digital_copy', 'digital_format', 'allow_digital_download',
                  'digital_access_url']

    def get_available_count(self, obj):
        return obj.available_copies

    def get_has_digital_copy(self, obj):
        return obj.has_digital_copy

    def get_digital_access_url(self, obj):
        request = self.context.get("request")
        if request is None or not obj.has_digital_copy:
            return None
        return request.build_absolute_uri(f"/api/books/{obj.id}/digital-access/")


class BookDetailSerializer(serializers.ModelSerializer):
    available_count = serializers.SerializerMethodField()
    waitlist_count = serializers.SerializerMethodField()
    has_digital_copy = serializers.SerializerMethodField()
    digital_access_url = serializers.SerializerMethodField()

    class Meta:
        model = Book
        fields = ['id', 'title', 'author', 'isbn', 'category', 'shelf', 'description',
                  'total_copies', 'available_copies', 'published_year', 'available_count',
                  'waitlist_count', 'has_digital_copy', 'digital_format',
                  'allow_digital_download', 'digital_access_url']

    def get_available_count(self, obj):
        return obj.available_copies

    def get_waitlist_count(self, obj):
        return obj.reservations.filter(status__in=['pending', 'notified']).count()

    def get_has_digital_copy(self, obj):
        return obj.has_digital_copy

    def get_digital_access_url(self, obj):
        request = self.context.get("request")
        if request is None or not obj.has_digital_copy:
            return None
        return request.build_absolute_uri(f"/api/books/{obj.id}/digital-access/")


class IssuedBookSerializer(serializers.ModelSerializer):
    book_detail = BookSerializer(source='book', read_only=True)
    is_overdue = serializers.SerializerMethodField()
    days_remaining = serializers.SerializerMethodField()
    can_renew = serializers.SerializerMethodField()
    overdue_days = serializers.SerializerMethodField()
    current_overdue_fine = serializers.SerializerMethodField()

    class Meta:
        model = IssuedBook
        fields = ['id', 'student', 'book', 'book_detail', 'issue_date', 'due_date',
                  'return_date', 'is_returned', 'renewal_count', 'max_renewals',
                  'is_overdue', 'days_remaining', 'can_renew', 'overdue_days',
                  'current_overdue_fine']

    def get_is_overdue(self, obj):
        return obj.is_overdue

    def get_days_remaining(self, obj):
        return obj.days_remaining

    def get_can_renew(self, obj):
        return False

    def get_overdue_days(self, obj):
        return obj.overdue_days

    def get_current_overdue_fine(self, obj):
        if obj.is_returned or obj.overdue_days <= 0:
            return 0.0
        settings = LibrarySettings.objects.first() or LibrarySettings()
        return float(settings.overdue_fine_per_day * obj.overdue_days)


class BookRenewalSerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source='issued_book.book.title', read_only=True)

    class Meta:
        model = BookRenewal
        fields = ['id', 'issued_book', 'book_title', 'renewal_date', 'old_due_date', 'new_due_date']


class BorrowHistorySerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source='book.title', read_only=True)
    book_author = serializers.CharField(source='book.author', read_only=True)
    status = serializers.SerializerMethodField()

    class Meta:
        model = BorrowHistory
        fields = ['id', 'student', 'book', 'book_title', 'book_author', 'issue_date',
                  'return_date', 'duration_days', 'status']

    def get_status(self, obj):
        return "Closed" if obj.return_date else "Active"


class BookReservationSerializer(serializers.ModelSerializer):
    book_detail = BookSerializer(source='book', read_only=True)
    estimated_days = serializers.SerializerMethodField()
    hold_expires_at = serializers.SerializerMethodField()
    hold_minutes_left = serializers.SerializerMethodField()

    class Meta:
        model = BookReservation
        fields = ['id', 'student', 'book', 'book_detail', 'reserved_date', 'queue_position',
                  'status', 'expected_available_date', 'estimated_days', 'hold_expires_at',
                  'hold_minutes_left']

    def get_estimated_days(self, obj):
        if obj.status == 'notified' and obj.expected_available_date:
            return 0
        if obj.expected_available_date:
            days = (obj.expected_available_date - timezone.now()).days
            return max(0, days)
        return None

    def get_hold_expires_at(self, obj):
        if obj.status == 'notified':
            return obj.expected_available_date
        return None

    def get_hold_minutes_left(self, obj):
        if obj.status != 'notified' or not obj.expected_available_date:
            return None
        seconds_left = (obj.expected_available_date - timezone.now()).total_seconds()
        if seconds_left <= 0:
            return 0
        return int(seconds_left // 60) + (1 if seconds_left % 60 else 0)


class FinePaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = FinePayment
        fields = ['id', 'fine', 'payment_date', 'amount_paid', 'payment_method', 'transaction_id']


class FineSerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source='issued_book.book.title', read_only=True, allow_null=True)
    payments = FinePaymentSerializer(many=True, read_only=True)

    class Meta:
        model = Fine
        fields = ['id', 'student', 'issued_book', 'book_title', 'fine_type', 'amount',
                  'issue_date', 'paid_date', 'is_paid', 'description', 'payments']


class NotificationSerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source='related_book.title', read_only=True, allow_null=True)
    notification_type_display = serializers.CharField(
        source='get_notification_type_display',
        read_only=True,
    )

    class Meta:
        model = Notification
        fields = ['id', 'student', 'notification_type', 'title', 'message', 'related_book',
                  'book_title', 'notification_type_display', 'related_issue', 'dedupe_key',
                  'is_read', 'read_at', 'created_at']


class PushDeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = PushDevice
        fields = ['id', 'token', 'platform', 'is_active', 'last_seen_at', 'created_at']


class AnnouncementSerializer(serializers.ModelSerializer):
    posted_by_username = serializers.CharField(source='posted_by.username', read_only=True, allow_null=True)

    class Meta:
        model = Announcement
        fields = ['id', 'title', 'content', 'posted_by', 'posted_by_username', 'is_active',
                  'image_url', 'created_at', 'updated_at', 'expires_at']


class LibrarySettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = LibrarySettings
        fields = ['borrow_days', 'max_books_per_student', 'overdue_fine_per_day',
                  'max_renewals', 'renewal_extends_days', 'updated_at']


class DashboardSummarySerializer(serializers.Serializer):
    currently_borrowed = serializers.SerializerMethodField()
    due_this_week = serializers.SerializerMethodField()
    overdue = serializers.SerializerMethodField()
    outstanding_fines = serializers.SerializerMethodField()
    pending_reservations = serializers.SerializerMethodField()
    announcements = serializers.SerializerMethodField()

    def get_currently_borrowed(self, obj):
        issued = IssuedBook.objects.filter(student=obj['student'], is_returned=False)
        return {
            'count': issued.count(),
            'books': IssuedBookSerializer(issued, many=True).data
        }

    def get_due_this_week(self, obj):
        today = timezone.now()
        week_end = today + timedelta(days=7)
        due_soon = IssuedBook.objects.filter(
            student=obj['student'],
            is_returned=False,
            due_date__gte=today,
            due_date__lte=week_end
        )
        return {
            'count': due_soon.count(),
            'books': IssuedBookSerializer(due_soon, many=True).data
        }

    def get_overdue(self, obj):
        overdue = IssuedBook.objects.filter(
            student=obj['student'],
            is_returned=False,
            due_date__lt=timezone.now()
        )
        return {
            'count': overdue.count(),
            'books': IssuedBookSerializer(overdue, many=True).data
        }

    def get_outstanding_fines(self, obj):
        fines = Fine.objects.filter(student=obj['student'], is_paid=False)
        total = sum(f.amount for f in fines)
        return {
            'count': fines.count(),
            'total_amount': float(total)
        }

    def get_pending_reservations(self, obj):
        reservations = BookReservation.objects.filter(
            student=obj['student'],
            status__in=['pending', 'notified']
        )
        return {
            'count': reservations.count()
        }

    def get_announcements(self, obj):
        announcements = Announcement.objects.filter(
            is_active=True,
            created_at__gte=timezone.now() - timedelta(days=7)
        )[:5]
        return AnnouncementSerializer(announcements, many=True).data
