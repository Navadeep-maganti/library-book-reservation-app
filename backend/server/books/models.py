from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta

User = get_user_model()


class Book(models.Model):
    title = models.CharField(max_length=255)
    author = models.CharField(max_length=255)
    isbn = models.CharField(max_length=20, unique=True)
    category = models.CharField(max_length=100, blank=True)
    shelf = models.CharField(max_length=50, blank=True)
    description = models.TextField(blank=True)
    digital_file = models.FileField(upload_to="books/digital/", null=True, blank=True)
    digital_external_url = models.URLField(blank=True)
    digital_read_url = models.URLField(blank=True)
    digital_format = models.CharField(max_length=20, blank=True)
    allow_digital_download = models.BooleanField(default=True)
    total_copies = models.PositiveIntegerField(default=1)
    available_copies = models.PositiveIntegerField(default=1)
    published_year = models.PositiveIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} - {self.author}"

    @property
    def has_digital_copy(self):
        return bool(self.digital_file or self.digital_external_url)


class IssuedBook(models.Model):
    student = models.ForeignKey(User, on_delete=models.CASCADE, related_name='issued_books')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='issued_records')
    issue_date = models.DateTimeField(auto_now_add=True)
    due_date = models.DateTimeField()
    return_date = models.DateTimeField(null=True, blank=True)
    is_returned = models.BooleanField(default=False)
    renewal_count = models.PositiveIntegerField(default=0)
    max_renewals = models.PositiveIntegerField(default=3)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-due_date']

    def __str__(self):
        return f"{self.student.username} - {self.book.title}"

    def save(self, *args, **kwargs):
        update_fields = kwargs.get("update_fields")
        if self.is_returned and self.return_date is None:
            self.return_date = timezone.now()
            if update_fields is not None:
                kwargs["update_fields"] = set(update_fields) | {"return_date"}

        super().save(*args, **kwargs)

        if self.is_returned:
            duration = max(0, (self.return_date - self.issue_date).days)
            history = BorrowHistory.objects.filter(
                student=self.student,
                book=self.book,
                issue_date=self.issue_date,
            ).first()
            if history is None:
                BorrowHistory.objects.create(
                    student=self.student,
                    book=self.book,
                    issue_date=self.issue_date,
                    return_date=self.return_date,
                    duration_days=duration,
                )
            else:
                updated_fields = []
                if history.return_date != self.return_date:
                    history.return_date = self.return_date
                    updated_fields.append("return_date")
                if history.duration_days != duration:
                    history.duration_days = duration
                    updated_fields.append("duration_days")
                if updated_fields:
                    history.save(update_fields=updated_fields)

    @property
    def is_overdue(self):
        return self.overdue_days > 0

    @property
    def overdue_days(self):
        reference_time = self.return_date or timezone.now()
        due_local_date = timezone.localtime(self.due_date).date()
        reference_local_date = timezone.localtime(reference_time).date()
        return max(0, (reference_local_date - due_local_date).days)

    @property
    def days_remaining(self):
        if self.is_returned:
            return 0
        return (self.due_date - timezone.now()).days


class BookRenewal(models.Model):
    issued_book = models.ForeignKey(IssuedBook, on_delete=models.CASCADE, related_name='renewals')
    renewal_date = models.DateTimeField(auto_now_add=True)
    old_due_date = models.DateTimeField()
    new_due_date = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Renewal: {self.issued_book.book.title} - {self.renewal_date}"


class BorrowHistory(models.Model):
    student = models.ForeignKey(User, on_delete=models.CASCADE, related_name='borrow_history')
    book = models.ForeignKey(Book, on_delete=models.CASCADE)
    issue_date = models.DateTimeField()
    return_date = models.DateTimeField()
    duration_days = models.PositiveIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-return_date']

    def __str__(self):
        return f"{self.student.username} - {self.book.title}"


class BookReservation(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('notified', 'Notified'),
        ('expired', 'Expired'),
        ('cancelled', 'Cancelled'),
        ('issued', 'Issued'),
    ]

    student = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reservations')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='reservations')
    reserved_date = models.DateTimeField(auto_now_add=True)
    queue_position = models.PositiveIntegerField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    expected_available_date = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['queue_position']

    def __str__(self):
        return f"{self.student.username} - {self.book.title} (Position: {self.queue_position})"

    def save(self, *args, **kwargs):
        previous_status = None
        if self.pk:
            previous_status = (
                BookReservation.objects.filter(pk=self.pk)
                .values_list("status", flat=True)
                .first()
            )

        super().save(*args, **kwargs)

        if self.status != "issued" or previous_status == "issued":
            return

        existing_issue = IssuedBook.objects.filter(
            student=self.student,
            book=self.book,
            is_returned=False,
        ).first()
        if existing_issue is not None:
            return

        settings = LibrarySettings.objects.first() or LibrarySettings()
        IssuedBook.objects.create(
            student=self.student,
            book=self.book,
            due_date=timezone.now() + timedelta(days=settings.borrow_days),
            max_renewals=settings.max_renewals,
        )


class Fine(models.Model):
    FINE_TYPE_CHOICES = [
        ('overdue', 'Overdue'),
        ('damage', 'Damage'),
        ('lost', 'Lost'),
    ]

    student = models.ForeignKey(User, on_delete=models.CASCADE, related_name='fines')
    issued_book = models.ForeignKey(IssuedBook, on_delete=models.SET_NULL, null=True, blank=True, related_name='fines')
    fine_type = models.CharField(max_length=20, choices=FINE_TYPE_CHOICES)
    amount = models.DecimalField(max_digits=8, decimal_places=2)
    issue_date = models.DateTimeField(auto_now_add=True)
    paid_date = models.DateTimeField(null=True, blank=True)
    is_paid = models.BooleanField(default=False)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-issue_date']

    def __str__(self):
        return f"Fine: {self.student.username} - Rs {self.amount} ({self.get_fine_type_display()})"


class FinePayment(models.Model):
    PAYMENT_METHOD_CHOICES = [
        ('cash', 'Cash'),
        ('card', 'Card'),
        ('online', 'Online'),
    ]

    fine = models.ForeignKey(Fine, on_delete=models.CASCADE, related_name='payments')
    payment_date = models.DateTimeField(auto_now_add=True)
    amount_paid = models.DecimalField(max_digits=8, decimal_places=2)
    payment_method = models.CharField(max_length=20, choices=PAYMENT_METHOD_CHOICES)
    transaction_id = models.CharField(max_length=100, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Payment: Rs {self.amount_paid} - {self.payment_date}"


class Notification(models.Model):
    NOTIFICATION_TYPE_CHOICES = [
        ('announcement', 'Announcement'),
        ('book_issued', 'Book Issued'),
        ('book_returned', 'Book Returned'),
        ('due_reminder', 'Due Reminder'),
        ('overdue_alert', 'Overdue Alert'),
        ('reservation_ready', 'Reservation Ready'),
        ('waiting_list', 'Waiting List'),
        ('fine_alert', 'Fine Alert'),
        ('system', 'System Notification'),
    ]

    student = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    notification_type = models.CharField(max_length=30, choices=NOTIFICATION_TYPE_CHOICES)
    title = models.CharField(max_length=255)
    message = models.TextField()
    related_book = models.ForeignKey(Book, on_delete=models.SET_NULL, null=True, blank=True)
    related_issue = models.ForeignKey(IssuedBook, on_delete=models.SET_NULL, null=True, blank=True)
    dedupe_key = models.CharField(max_length=255, blank=True, db_index=True)
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Notification: {self.student.username} - {self.title}"


class PushDevice(models.Model):
    PLATFORM_CHOICES = [
        ('android', 'Android'),
        ('ios', 'iOS'),
    ]

    student = models.ForeignKey(User, on_delete=models.CASCADE, related_name='push_devices')
    token = models.TextField(unique=True)
    platform = models.CharField(max_length=20, choices=PLATFORM_CHOICES)
    is_active = models.BooleanField(default=True)
    last_seen_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-last_seen_at']

    def __str__(self):
        return f"PushDevice: {self.student.username} ({self.platform})"


class Announcement(models.Model):
    title = models.CharField(max_length=255)
    content = models.TextField()
    posted_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, limit_choices_to={'role': 'librarian'})
    is_active = models.BooleanField(default=True)
    image_url = models.URLField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    expires_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Announcement: {self.title}"


class LibrarySettings(models.Model):
    borrow_days = models.PositiveIntegerField(default=14)
    max_books_per_student = models.PositiveIntegerField(default=5)
    overdue_fine_per_day = models.DecimalField(max_digits=6, decimal_places=2, default=10.00)
    max_renewals = models.PositiveIntegerField(default=3)
    renewal_extends_days = models.PositiveIntegerField(default=7)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return "Library Settings"

    class Meta:
        verbose_name_plural = "Library Settings"
