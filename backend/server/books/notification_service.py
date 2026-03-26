from datetime import timedelta

from django.utils import timezone

from .models import Announcement, Fine, IssuedBook, Notification
from .push_service import send_notification_push


DUE_REMINDER_OFFSETS = (3, 1, 0)
ANNOUNCEMENT_LOOKBACK_DAYS = 14


def create_notification(
    *,
    student,
    notification_type,
    title,
    message,
    related_book=None,
    related_issue=None,
    dedupe_key="",
):
    if dedupe_key:
        existing = Notification.objects.filter(
            student=student,
            dedupe_key=dedupe_key,
        ).first()
        if existing is not None:
            return existing, False

    notification = Notification.objects.create(
        student=student,
        notification_type=notification_type,
        title=title,
        message=message,
        related_book=related_book,
        related_issue=related_issue,
        dedupe_key=dedupe_key,
    )
    send_notification_push(notification)
    return notification, True


def sync_user_notifications(student):
    created = []
    created.extend(_sync_due_notifications(student))
    created.extend(_sync_fine_notifications(student))
    created.extend(_sync_announcement_notifications(student))
    return created


def _sync_due_notifications(student):
    created = []
    today = timezone.localdate()
    issues = IssuedBook.objects.filter(
        student=student,
        is_returned=False,
    ).select_related("book")

    for issued in issues:
        due_local_date = timezone.localtime(issued.due_date).date()
        days_until_due = (due_local_date - today).days

        if days_until_due in DUE_REMINDER_OFFSETS:
            if days_until_due == 0:
                title = f"Due Today: {issued.book.title}"
                message = (
                    f'"{issued.book.title}" is due today. '
                    "Return or renew it before the deadline to avoid a fine."
                )
            elif days_until_due == 1:
                title = f"Due Tomorrow: {issued.book.title}"
                message = (
                    f'"{issued.book.title}" is due tomorrow. '
                    "Please plan your return to avoid overdue charges."
                )
            else:
                title = f"Upcoming Due Date: {issued.book.title}"
                message = (
                    f'"{issued.book.title}" is due in {days_until_due} days on '
                    f"{due_local_date.strftime('%d %b %Y')}."
                )

            notification, was_created = create_notification(
                student=student,
                notification_type="due_reminder",
                title=title,
                message=message,
                related_book=issued.book,
                related_issue=issued,
                dedupe_key=f"issued:{issued.id}:due:{days_until_due}",
            )
            if was_created:
                created.append(notification)
            continue

        if days_until_due < 0:
            overdue_days = abs(days_until_due)
            notification, was_created = create_notification(
                student=student,
                notification_type="overdue_alert",
                title=f"Overdue Book: {issued.book.title}",
                message=(
                    f'"{issued.book.title}" is overdue by {overdue_days} day(s). '
                    "Please return it as soon as possible."
                ),
                related_book=issued.book,
                related_issue=issued,
                dedupe_key=f"issued:{issued.id}:overdue:{overdue_days}",
            )
            if was_created:
                created.append(notification)

    return created


def _sync_fine_notifications(student):
    created = []
    fines = Fine.objects.filter(
        student=student,
        is_paid=False,
    ).select_related("issued_book__book")

    for fine in fines:
        book = fine.issued_book.book if fine.issued_book_id and fine.issued_book else None
        book_title = book.title if book is not None else "your library account"
        notification, was_created = create_notification(
            student=student,
            notification_type="fine_alert",
            title=f"Outstanding Fine: Rs {fine.amount}",
            message=(
                f"You have an unpaid {fine.get_fine_type_display().lower()} fine "
                f"for {book_title}."
            ),
            related_book=book,
            related_issue=fine.issued_book,
            dedupe_key=f"fine:{fine.id}:unpaid",
        )
        if was_created:
            created.append(notification)

    return created


def _sync_announcement_notifications(student):
    created = []
    cutoff = timezone.now() - timedelta(days=ANNOUNCEMENT_LOOKBACK_DAYS)
    announcements = Announcement.objects.filter(
        is_active=True,
        created_at__gte=cutoff,
    )

    for announcement in announcements:
        notification, was_created = create_notification(
            student=student,
            notification_type="announcement",
            title=announcement.title,
            message=announcement.content,
            dedupe_key=f"announcement:{announcement.id}",
        )
        if was_created:
            created.append(notification)

    return created
