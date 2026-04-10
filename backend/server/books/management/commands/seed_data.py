from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from books.models import (
    Announcement,
    Book,
    BookRenewal,
    BookReservation,
    BorrowHistory,
    Fine,
    FinePayment,
    IssuedBook,
    LibrarySettings,
    Notification,
)

User = get_user_model()


LIBRARIANS = [
    {
        "username": "admin",
        "password": "admin",
        "email": "admin@library.local",
        "student_id": "ADMIN-001",
        "role": User.Roles.LIBRARIAN,
        "is_staff": True,
        "is_superuser": True,
    },
    {
        "username": "librarian1",
        "password": "Lib@12345",
        "email": "librarian1@library.local",
        "student_id": "LIB-001",
        "role": User.Roles.LIBRARIAN,
        "is_staff": True,
        "is_superuser": True,
    },
    {
        "username": "librarian2",
        "password": "Lib@12345",
        "email": "librarian2@library.local",
        "student_id": "LIB-002",
        "role": User.Roles.LIBRARIAN,
        "is_staff": True,
        "is_superuser": False,
    },
]


STUDENTS = [
    {
        "username": "student1",
        "password": "Student@123",
        "email": "student1@library.local",
        "student_id": "202400001",
    },
    {
        "username": "student2",
        "password": "Student@123",
        "email": "student2@library.local",
        "student_id": "202400002",
    },
    {
        "username": "student3",
        "password": "Student@123",
        "email": "student3@library.local",
        "student_id": "202400003",
    },
    {
        "username": "student4",
        "password": "Student@123",
        "email": "student4@library.local",
        "student_id": "202400004",
    },
    {
        "username": "student5",
        "password": "Student@123",
        "email": "student5@library.local",
        "student_id": "202400005",
    },
]


BOOKS = [
    {
        "isbn": "9781119800368",
        "title": "Operating Systems",
        "author": "Abraham Silberschatz",
        "category": "Computer Science",
        "shelf": "CS-A12",
        "description": "Core concepts in process management, memory, filesystems, and concurrency.",
        "total_copies": 8,
        "available_copies": 5,
        "published_year": 2018,
    },
    {
        "isbn": "9780072465631",
        "title": "Database Management Systems",
        "author": "Raghu Ramakrishnan",
        "category": "Computer Science",
        "shelf": "CS-B08",
        "description": "Relational design, transactions, indexing, and query optimization.",
        "total_copies": 6,
        "available_copies": 3,
        "published_year": 2002,
    },
    {
        "isbn": "9780132126953",
        "title": "Computer Networks",
        "author": "Andrew S. Tanenbaum",
        "category": "Computer Science",
        "shelf": "CS-A04",
        "description": "Network layers, protocols, routing, and performance fundamentals.",
        "total_copies": 7,
        "available_copies": 4,
        "published_year": 2011,
    },
    {
        "isbn": "9780132350884",
        "title": "Clean Code",
        "author": "Robert C. Martin",
        "category": "Software Engineering",
        "shelf": "SE-C11",
        "description": "Practical guidance for writing maintainable, readable software.",
        "total_copies": 5,
        "available_copies": 2,
        "published_year": 2008,
    },
    {
        "isbn": "9780132143011",
        "title": "Distributed Systems",
        "author": "George Coulouris",
        "category": "Computer Science",
        "shelf": "CS-D02",
        "description": "Architectures, coordination, fault tolerance, and distributed design.",
        "total_copies": 4,
        "available_copies": 1,
        "published_year": 2011,
    },
    {
        "isbn": "9780262046305",
        "title": "Introduction to Algorithms",
        "author": "Thomas H. Cormen",
        "category": "Algorithms",
        "shelf": "CS-AL09",
        "description": "Foundational algorithms and data structures for advanced study.",
        "total_copies": 6,
        "available_copies": 2,
        "published_year": 2022,
    },
    {
        "isbn": "9780201633610",
        "title": "Design Patterns",
        "author": "Erich Gamma",
        "category": "Software Engineering",
        "shelf": "SE-DP01",
        "description": "Classic reusable object-oriented design patterns.",
        "total_copies": 4,
        "available_copies": 1,
        "published_year": 1994,
    },
    {
        "isbn": "9780201616224",
        "title": "The Pragmatic Programmer",
        "author": "Andrew Hunt",
        "category": "Software Engineering",
        "shelf": "SE-PP02",
        "description": "Timeless habits and practical techniques for software professionals.",
        "total_copies": 5,
        "available_copies": 2,
        "published_year": 1999,
    },
    {
        "isbn": "9781593279288",
        "title": "Python Crash Course",
        "author": "Eric Matthes",
        "category": "Programming",
        "shelf": "PROG-PY02",
        "description": "Beginner-friendly introduction to Python with real projects.",
        "total_copies": 6,
        "available_copies": 4,
        "published_year": 2019,
    },
    {
        "isbn": "9780262035613",
        "title": "Deep Learning",
        "author": "Ian Goodfellow",
        "category": "Data Science",
        "shelf": "DS-DL02",
        "description": "Comprehensive deep learning theory and practice.",
        "total_copies": 3,
        "available_copies": 0,
        "published_year": 2016,
    },
    {
        "isbn": "9780131873032",
        "title": "Speech and Language Processing",
        "author": "Daniel Jurafsky",
        "category": "Data Science",
        "shelf": "DS-NLP03",
        "description": "NLP concepts spanning language models, parsing, and semantics.",
        "total_copies": 4,
        "available_copies": 0,
        "published_year": 2008,
    },
    {
        "isbn": "9783319110288",
        "title": "Linear Algebra Done Right",
        "author": "Sheldon Axler",
        "category": "Mathematics",
        "shelf": "MATH-LA03",
        "description": "Rigorous linear algebra text popular in undergraduate programs.",
        "total_copies": 5,
        "available_copies": 3,
        "published_year": 2015,
    },
]


class Command(BaseCommand):
    help = "Seed the database with deterministic demo users, books, and circulation data."

    @transaction.atomic
    def handle(self, *args, **options):
        now = timezone.now()
        self.stdout.write("Seeding library demo data...")

        settings_obj, _ = LibrarySettings.objects.update_or_create(
            id=1,
            defaults={
                "borrow_days": 14,
                "max_books_per_student": 5,
                "overdue_fine_per_day": Decimal("10.00"),
                "max_renewals": 3,
                "renewal_extends_days": 7,
            },
        )
        self.stdout.write(self.style.SUCCESS("Library settings ready"))

        librarians = {
            user["username"]: self._upsert_user(user) for user in LIBRARIANS
        }
        students = {
            user["username"]: self._upsert_user(
                {**user, "role": User.Roles.STUDENT, "is_staff": False, "is_superuser": False}
            )
            for user in STUDENTS
        }
        self.stdout.write(self.style.SUCCESS("Users ready"))

        books = {book["isbn"]: self._upsert_book(book) for book in BOOKS}
        self.stdout.write(self.style.SUCCESS(f"{len(books)} books ready"))

        issued_specs = [
            ("student1", "9781119800368", now - timedelta(days=10), now + timedelta(days=4), 0),
            ("student1", "9780201633610", now - timedelta(days=16), now - timedelta(days=2), 1),
            ("student2", "9780072465631", now - timedelta(days=8), now + timedelta(days=6), 0),
            ("student2", "9780262035613", now - timedelta(days=18), now - timedelta(days=1), 2),
            ("student3", "9780132126953", now - timedelta(days=5), now + timedelta(days=9), 0),
            ("student4", "9780132350884", now - timedelta(days=11), now + timedelta(days=2), 1),
            ("student5", "9780131873032", now - timedelta(days=13), now - timedelta(days=3), 0),
        ]
        issued_records = {}
        for username, isbn, issue_date, due_date, renewal_count in issued_specs:
            issued_records[(username, isbn)] = self._upsert_issued_book(
                student=students[username],
                book=books[isbn],
                issue_date=issue_date,
                due_date=due_date,
                renewal_count=renewal_count,
                max_renewals=settings_obj.max_renewals,
            )
        self.stdout.write(self.style.SUCCESS("Issued books ready"))

        renewal = issued_records[("student4", "9780132350884")]
        BookRenewal.objects.update_or_create(
            issued_book=renewal,
            old_due_date=renewal.due_date - timedelta(days=settings_obj.renewal_extends_days),
            new_due_date=renewal.due_date,
            defaults={},
        )

        history_specs = [
            ("student1", "9781593279288", now - timedelta(days=40), now - timedelta(days=26)),
            ("student1", "9780262046305", now - timedelta(days=70), now - timedelta(days=55)),
            ("student2", "9783319110288", now - timedelta(days=28), now - timedelta(days=14)),
            ("student3", "9780201616224", now - timedelta(days=33), now - timedelta(days=18)),
            ("student4", "9780132143011", now - timedelta(days=60), now - timedelta(days=46)),
            ("student5", "9781119800368", now - timedelta(days=24), now - timedelta(days=9)),
        ]
        for username, isbn, issue_date, return_date in history_specs:
            BorrowHistory.objects.update_or_create(
                student=students[username],
                book=books[isbn],
                issue_date=issue_date,
                defaults={
                    "return_date": return_date,
                    "duration_days": (return_date - issue_date).days,
                },
            )
        self.stdout.write(self.style.SUCCESS("Borrow history ready"))

        fine1, _ = Fine.objects.update_or_create(
            student=students["student2"],
            issued_book=issued_records[("student2", "9780262035613")],
            fine_type="overdue",
            defaults={
                "amount": Decimal("30.00"),
                "is_paid": False,
                "paid_date": None,
                "description": "Overdue fine for late return risk.",
            },
        )
        fine2, _ = Fine.objects.update_or_create(
            student=students["student5"],
            issued_book=issued_records[("student5", "9780131873032")],
            fine_type="damage",
            defaults={
                "amount": Decimal("60.00"),
                "is_paid": True,
                "paid_date": now - timedelta(days=1),
                "description": "Cover damage settlement.",
            },
        )
        FinePayment.objects.update_or_create(
            fine=fine2,
            amount_paid=Decimal("60.00"),
            payment_method="online",
            defaults={"transaction_id": "TXN-DEMO-0001"},
        )
        self.stdout.write(self.style.SUCCESS("Fines ready"))

        reservation_specs = [
            ("student3", "9780262035613", 1, "pending"),
            ("student4", "9780262035613", 2, "pending"),
            ("student1", "9780131873032", 1, "notified"),
        ]
        for username, isbn, queue_position, status in reservation_specs:
            BookReservation.objects.update_or_create(
                student=students[username],
                book=books[isbn],
                defaults={
                    "queue_position": queue_position,
                    "status": status,
                    "expected_available_date": now + timedelta(days=3 + queue_position),
                },
            )
        self.stdout.write(self.style.SUCCESS("Reservations ready"))

        announcement_specs = [
            (
                "Extended Library Hours",
                "Library stays open until 11 PM during exam week.",
            ),
            (
                "New AI Titles Added",
                "Fresh machine learning and NLP books are now available on the DS shelves.",
            ),
            (
                "Fine Waiver Window",
                "Return overdue books before Friday to receive a 50% fine waiver.",
            ),
        ]
        for title, content in announcement_specs:
            Announcement.objects.update_or_create(
                title=title,
                defaults={
                    "content": content,
                    "posted_by": librarians["librarian1"],
                    "is_active": True,
                    "expires_at": now + timedelta(days=14),
                },
            )
        self.stdout.write(self.style.SUCCESS("Announcements ready"))

        notification_specs = [
            (
                "student1",
                "due_reminder",
                "Book due soon",
                "Your copy of Operating Systems is due in 4 days.",
                "9781119800368",
            ),
            (
                "student2",
                "fine_alert",
                "Outstanding fine",
                "You have an unpaid overdue fine of Rs 30.00.",
                "9780262035613",
            ),
            (
                "student3",
                "waiting_list",
                "Reservation queued",
                "You are first in line for Deep Learning.",
                "9780262035613",
            ),
            (
                "student5",
                "overdue_alert",
                "Book overdue",
                "Speech and Language Processing is now overdue by 3 days.",
                "9780131873032",
            ),
        ]
        for username, notif_type, title, message, isbn in notification_specs:
            Notification.objects.update_or_create(
                student=students[username],
                title=title,
                defaults={
                    "notification_type": notif_type,
                    "message": message,
                    "related_book": books[isbn],
                    "is_read": False,
                    "dedupe_key": f"seed:{username}:{notif_type}:{isbn}",
                },
            )
        self.stdout.write(self.style.SUCCESS("Notifications ready"))
        self.stdout.write(self.style.SUCCESS("Demo data seeding completed successfully."))

    def _upsert_user(self, spec):
        password = spec["password"]
        user, _ = User.objects.update_or_create(
            username=spec["username"],
            defaults={
                "email": spec["email"],
                "student_id": spec["student_id"],
                "role": spec["role"],
                "is_staff": spec["is_staff"],
                "is_superuser": spec["is_superuser"],
                "is_active": True,
            },
        )
        user.set_password(password)
        user.save(update_fields=["password"])
        return user

    def _upsert_book(self, spec):
        book, _ = Book.objects.update_or_create(
            isbn=spec["isbn"],
            defaults={
                "title": spec["title"],
                "author": spec["author"],
                "category": spec["category"],
                "shelf": spec["shelf"],
                "description": spec["description"],
                "total_copies": spec["total_copies"],
                "available_copies": spec["available_copies"],
                "published_year": spec["published_year"],
            },
        )
        return book

    def _upsert_issued_book(
        self,
        *,
        student,
        book,
        issue_date,
        due_date,
        renewal_count,
        max_renewals,
    ):
        issued_book, _ = IssuedBook.objects.update_or_create(
            student=student,
            book=book,
            is_returned=False,
            defaults={
                "issue_date": issue_date,
                "due_date": due_date,
                "renewal_count": renewal_count,
                "max_renewals": max_renewals,
                "return_date": None,
            },
        )
        return issued_book
