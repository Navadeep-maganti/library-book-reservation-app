from django.contrib import admin
from .models import (
    Book, IssuedBook, BookRenewal, BorrowHistory, BookReservation,
    Fine, FinePayment, Notification, Announcement, LibrarySettings
)


@admin.register(Book)
class BookAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "author",
        "isbn",
        "category",
        "available_copies",
        "total_copies",
    )
    search_fields = ("title", "author", "isbn")
    list_filter = ("category",)


@admin.register(IssuedBook)
class IssuedBookAdmin(admin.ModelAdmin):
    list_display = ("student", "book", "issue_date", "due_date", "is_returned")
    list_filter = ("is_returned", "issue_date")
    search_fields = ("student__username", "book__title")
    readonly_fields = ("issue_date", "created_at")


@admin.register(BookRenewal)
class BookRenewalAdmin(admin.ModelAdmin):
    list_display = ("issued_book", "renewal_date", "old_due_date", "new_due_date")
    readonly_fields = ("renewal_date", "created_at")


@admin.register(BorrowHistory)
class BorrowHistoryAdmin(admin.ModelAdmin):
    list_display = ("student", "book", "issue_date", "return_date", "duration_days")
    list_filter = ("issue_date", "return_date")
    search_fields = ("student__username", "book__title")


@admin.register(BookReservation)
class BookReservationAdmin(admin.ModelAdmin):
    list_display = ("student", "book", "queue_position", "status", "reserved_date")
    list_filter = ("status", "reserved_date")
    search_fields = ("student__username", "book__title")
    readonly_fields = ("reserved_date", "created_at")


@admin.register(Fine)
class FineAdmin(admin.ModelAdmin):
    list_display = ("student", "fine_type", "amount", "is_paid", "issue_date")
    list_filter = ("fine_type", "is_paid", "issue_date")
    search_fields = ("student__username", "issued_book__book__title")
    readonly_fields = ("issue_date", "created_at")


@admin.register(FinePayment)
class FinePaymentAdmin(admin.ModelAdmin):
    list_display = ("fine", "amount_paid", "payment_method", "payment_date")
    list_filter = ("payment_method", "payment_date")
    readonly_fields = ("payment_date", "created_at")


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("student", "notification_type", "title", "is_read", "created_at")
    list_filter = ("notification_type", "is_read", "created_at")
    search_fields = ("student__username", "title")
    readonly_fields = ("created_at", "read_at")


@admin.register(Announcement)
class AnnouncementAdmin(admin.ModelAdmin):
    list_display = ("title", "is_active", "posted_by", "created_at")
    list_filter = ("is_active", "created_at")
    search_fields = ("title", "content")
    readonly_fields = ("created_at", "updated_at")


@admin.register(LibrarySettings)
class LibrarySettingsAdmin(admin.ModelAdmin):
    list_display = (
        "borrow_days",
        "max_books_per_student",
        "overdue_fine_per_day",
        "max_renewals",
    )

