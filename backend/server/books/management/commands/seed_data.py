from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta
from books.models import (
    Book, IssuedBook, BookRenewal, BorrowHistory, BookReservation,
    Fine, Notification, Announcement, LibrarySettings
)
import random

User = get_user_model()


class Command(BaseCommand):
    help = 'Seed the database with sample data'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Starting data seeding...'))

        # Create library settings
        settings, _ = LibrarySettings.objects.get_or_create(
            id=1,
            defaults={
                'borrow_days': 14,
                'max_books_per_student': 5,
                'overdue_fine_per_day': 10.0,
                'max_renewals': 3,
                'renewal_extends_days': 7,
            }
        )
        self.stdout.write('[OK] Library settings created')

        # Create sample books if they don't exist
        if Book.objects.count() < 50:
            books_data = [
                ('Operating Systems', 'Silberschatz', '978-1119800368', 'Computer Science', 'CS-A12'),
                ('Database Systems', 'Ramakrishnan', '978-0072465631', 'Computer Science', 'CS-B08'),
                ('Computer Networks', 'Tanenbaum', '978-0132126953', 'Computer Science', 'CS-A04'),
                ('Clean Code', 'Robert C. Martin', '978-0132350884', 'Software Engineering', 'SE-C11'),
                ('Distributed Systems', 'Coulouris', '978-0132143011', 'Computer Science', 'CS-D02'),
                ('Introduction to Algorithms', 'Cormen', '978-0262046305', 'Computer Science', 'CS-AL09'),
                ('Data Mining Concepts', 'Han and Kamber', '978-0123814791', 'Data Science', 'CS-DM05'),
                ('Design Patterns', 'Gang of Four', '978-0201633610', 'Software Engineering', 'SE-DP01'),
                ('The Pragmatic Programmer', 'Hunt and Thomas', '978-0201616224', 'Software Engineering', 'SE-PP02'),
                ('Code Complete', 'Steve McConnell', '978-0735619678', 'Software Engineering', 'SE-CC03'),
                ('Refactoring', 'Martin Fowler', '978-0201485677', 'Software Engineering', 'SE-RF04'),
                ('The C Programming Language', 'Kernighan', '978-0131103627', 'Programming', 'PROG-C01'),
                ('Python Crash Course', 'Eric Matthes', '978-1593279288', 'Programming', 'PROG-PY02'),
                ('JavaScript: The Good Parts', 'Douglas Crockford', '978-0596517748', 'Programming', 'PROG-JS03'),
                ('Machine Learning Basics', 'Andrew Ng', '978-0262019416', 'Data Science', 'DS-ML01'),
                ('Deep Learning', 'Goodfellow', '978-0262035613', 'Data Science', 'DS-DL02'),
                ('Natural Language Processing', 'Jurafsky', '978-0131873032', 'Data Science', 'DS-NLP03'),
                ('Introduction to Statistics', 'Ross', '978-0123743886', 'Mathematics', 'MATH-ST01'),
                ('Discrete Mathematics', 'Rosen', '978-0073383087', 'Mathematics', 'MATH-DM02'),
                ('Linear Algebra Done Right', 'Axler', '978-3319110288', 'Mathematics', 'MATH-LA03'),
            ]

            for title, author, isbn, category, shelf in books_data:
                Book.objects.get_or_create(
                    isbn=isbn,
                    defaults={
                        'title': title,
                        'author': author,
                        'category': category,
                        'shelf': shelf,
                        'total_copies': random.randint(2, 8),
                        'available_copies': random.randint(0, 5),
                        'published_year': random.randint(2010, 2023),
                    }
                )
            self.stdout.write('[OK] %d books in database' % Book.objects.count())

        # Create sample student users with borrowing patterns
        student_ids = ['202400001', '202400002', '202400003', '202400004', '202400005']
        for i, student_id in enumerate(student_ids):
            user, created = User.objects.get_or_create(
                username=f'student{i+1}',
                defaults={
                    'student_id': student_id,
                    'role': 'student',
                    'email': f'student{i+1}@university.edu',
                }
            )
            if created:
                user.set_password(f'student{i+1}')
                user.save()

        self.stdout.write('[OK] Student users created/verified')

        # Create sample issued books (current borrowings)
        students = User.objects.filter(role='student')
        books = list(Book.objects.all())

        for student in students:
            # Each student has 2-4 currently borrowed books
            num_books = random.randint(2, 4)
            borrowed_books = random.sample(books, min(num_books, len(books)))

            for book in borrowed_books:
                # Check if not already issued
                if not IssuedBook.objects.filter(student=student, book=book, is_returned=False).exists():
                    # Create with various due dates
                    days_until_due = random.randint(-5, 14)
                    due_date = timezone.now() + timedelta(days=days_until_due)
                    issue_date = due_date - timedelta(days=10)

                    IssuedBook.objects.create(
                        student=student,
                        book=book,
                        issue_date=issue_date,
                        due_date=due_date,
                        is_returned=False,
                        renewal_count=random.randint(0, 2),
                        max_renewals=3,
                    )

        self.stdout.write('[OK] Issued books created')

        # Create sample borrow history
        for student in students:
            for _ in range(random.randint(3, 8)):
                book = random.choice(books)
                return_date = timezone.now() - timedelta(days=random.randint(5, 120))
                issue_date = return_date - timedelta(days=random.randint(10, 30))

                BorrowHistory.objects.get_or_create(
                    student=student,
                    book=book,
                    issue_date=issue_date,
                    return_date=return_date,
                    defaults={
                        'duration_days': (return_date - issue_date).days
                    }
                )

        self.stdout.write('[OK] Borrow history created')

        # Create sample fines
        for student in students:
            # Create 1-3 fines per student
            num_fines = random.randint(0, 3)
            for _ in range(num_fines):
                is_paid = random.random() > 0.4  # 60% chance of being unpaid

                Fine.objects.create(
                    student=student,
                    fine_type=random.choice(['overdue', 'damage']),
                    amount=random.choice([15, 30, 45, 60, 90]),
                    issue_date=timezone.now() - timedelta(days=random.randint(1, 30)),
                    paid_date=timezone.now() - timedelta(days=random.randint(1, 10)) if is_paid else None,
                    is_paid=is_paid,
                    description='Overdue fine' if random.random() > 0.5 else 'Damage fine'
                )

        self.stdout.write('[OK] Fines created')

        # Create sample waiting list / reservations
        for student in random.sample(list(students), min(3, len(students))):
            # 1-2 reservations per student
            num_reservations = random.randint(1, 2)
            unavailable_books = [b for b in books if b.available_copies == 0]
            if unavailable_books:
                for book in random.sample(unavailable_books, min(num_reservations, len(unavailable_books))):
                    if not BookReservation.objects.filter(student=student, book=book).exists():
                        # Get queue position
                        queue_pos = BookReservation.objects.filter(book=book).count() + 1
                        BookReservation.objects.create(
                            student=student,
                            book=book,
                            queue_position=queue_pos,
                            status=random.choice(['pending', 'notified']),
                        )

        self.stdout.write('[OK] Reservations created')

        # Create sample announcements
        announcements_data = [
            ('Extended Library Hours', 'Library will remain open until 11 PM during exams.', 'Info'),
            ('Digital Access Maintenance', 'E-journal portal maintenance Saturday 8-10 AM.', 'Scheduled'),
            ('Fine Waiver Window', '50% fine waiver for returns before March 5.', 'Important'),
            ('New Book Arrivals', 'Check out new books in the Data Science section!', 'Info'),
            ('Library Holiday Hours', 'Library closed on national holidays.', 'Important'),
        ]

        for title, content, category in announcements_data:
            Announcement.objects.get_or_create(
                title=title,
                defaults={
                    'content': content,
                    'is_active': True,
                    'created_at': timezone.now() - timedelta(days=random.randint(1, 7)),
                }
            )

        self.stdout.write('[OK] Announcements created')

        # Create sample notifications
        for student in students[:3]:  # Only for first 3 students
            # Create 3-5 notifications per student
            for _ in range(random.randint(3, 5)):
                notif_type = random.choice(['due_reminder', 'fine_alert', 'system'])
                book = random.choice(books) if random.random() > 0.5 else None

                Notification.objects.create(
                    student=student,
                    notification_type=notif_type,
                    title=f'Test Notification {random.randint(1, 100)}',
                    message='This is a sample notification for testing.',
                    related_book=book,
                    is_read=random.random() > 0.3,
                    created_at=timezone.now() - timedelta(hours=random.randint(1, 72)),
                )

        self.stdout.write('[OK] Notifications created')
        self.stdout.write(self.style.SUCCESS('All data seeding completed successfully!'))


        # Create sample books if they don't exist
        if Book.objects.count() < 50:
            books_data = [
                ('Operating Systems', 'Silberschatz', '978-1119800368', 'Computer Science', 'CS-A12'),
                ('Database Systems', 'Ramakrishnan', '978-0072465631', 'Computer Science', 'CS-B08'),
                ('Computer Networks', 'Tanenbaum', '978-0132126953', 'Computer Science', 'CS-A04'),
                ('Clean Code', 'Robert C. Martin', '978-0132350884', 'Software Engineering', 'SE-C11'),
                ('Distributed Systems', 'Coulouris', '978-0132143011', 'Computer Science', 'CS-D02'),
                ('Introduction to Algorithms', 'Cormen', '978-0262046305', 'Computer Science', 'CS-AL09'),
                ('Data Mining Concepts', 'Han and Kamber', '978-0123814791', 'Data Science', 'CS-DM05'),
                ('Design Patterns', 'Gang of Four', '978-0201633610', 'Software Engineering', 'SE-DP01'),
                ('The Pragmatic Programmer', 'Hunt and Thomas', '978-0201616224', 'Software Engineering', 'SE-PP02'),
                ('Code Complete', 'Steve McConnell', '978-0735619678', 'Software Engineering', 'SE-CC03'),
                ('Refactoring', 'Martin Fowler', '978-0201485677', 'Software Engineering', 'SE-RF04'),
                ('The C Programming Language', 'Kernighan', '978-0131103627', 'Programming', 'PROG-C01'),
                ('Python Crash Course', 'Eric Matthes', '978-1593279288', 'Programming', 'PROG-PY02'),
                ('JavaScript: The Good Parts', 'Douglas Crockford', '978-0596517748', 'Programming', 'PROG-JS03'),
                ('Machine Learning Basics', 'Andrew Ng', '978-0262019416', 'Data Science', 'DS-ML01'),
                ('Deep Learning', 'Goodfellow', '978-0262035613', 'Data Science', 'DS-DL02'),
                ('Natural Language Processing', 'Jurafsky', '978-0131873032', 'Data Science', 'DS-NLP03'),
                ('Introduction to Statistics', 'Ross', '978-0123743886', 'Mathematics', 'MATH-ST01'),
                ('Discrete Mathematics', 'Rosen', '978-0073383087', 'Mathematics', 'MATH-DM02'),
                ('Linear Algebra Done Right', 'Axler', '978-3319110288', 'Mathematics', 'MATH-LA03'),
            ]

            for title, author, isbn, category, shelf in books_data:
                Book.objects.get_or_create(
                    isbn=isbn,
                    defaults={
                        'title': title,
                        'author': author,
                        'category': category,
                        'shelf': shelf,
                        'total_copies': random.randint(2, 8),
                        'available_copies': random.randint(0, 5),
                        'published_year': random.randint(2010, 2023),
                    }
                )
            self.stdout.write(f'✓ {Book.objects.count()} books in database')

        # Create sample student users with borrowing patterns
        student_ids = ['202400001', '202400002', '202400003', '202400004', '202400005']
        for i, student_id in enumerate(student_ids):
            user, created = User.objects.get_or_create(
                username=f'student{i+1}',
                defaults={
                    'student_id': student_id,
                    'role': 'student',
                    'email': f'student{i+1}@university.edu',
                }
            )
            if created:
                user.set_password(f'student{i+1}')
                user.save()

        self.stdout.write('✓ Student users created/verified')

        # Create sample issued books (current borrowings)
        students = User.objects.filter(role='student')
        books = list(Book.objects.all())

        for student in students:
            # Each student has 2-4 currently borrowed books
            num_books = random.randint(2, 4)
            borrowed_books = random.sample(books, min(num_books, len(books)))

            for book in borrowed_books:
                # Check if not already issued
                if not IssuedBook.objects.filter(student=student, book=book, is_returned=False).exists():
                    # Create with various due dates
                    days_until_due = random.randint(-5, 14)
                    due_date = timezone.now() + timedelta(days=days_until_due)
                    issue_date = due_date - timedelta(days=10)

                    IssuedBook.objects.create(
                        student=student,
                        book=book,
                        issue_date=issue_date,
                        due_date=due_date,
                        is_returned=False,
                        renewal_count=random.randint(0, 2),
                        max_renewals=3,
                    )

        self.stdout.write(f'✓ Issued books created')

        # Create sample borrow history
        for student in students:
            for _ in range(random.randint(3, 8)):
                book = random.choice(books)
                return_date = timezone.now() - timedelta(days=random.randint(5, 120))
                issue_date = return_date - timedelta(days=random.randint(10, 30))

                BorrowHistory.objects.get_or_create(
                    student=student,
                    book=book,
                    issue_date=issue_date,
                    return_date=return_date,
                    defaults={
                        'duration_days': (return_date - issue_date).days
                    }
                )

        self.stdout.write('✓ Borrow history created')

        # Create sample fines
        for student in students:
            # Create 1-3 fines per student
            num_fines = random.randint(0, 3)
            for _ in range(num_fines):
                is_paid = random.random() > 0.4  # 60% chance of being unpaid

                Fine.objects.create(
                    student=student,
                    fine_type=random.choice(['overdue', 'damage']),
                    amount=random.choice([15, 30, 45, 60, 90]),
                    issue_date=timezone.now() - timedelta(days=random.randint(1, 30)),
                    paid_date=timezone.now() - timedelta(days=random.randint(1, 10)) if is_paid else None,
                    is_paid=is_paid,
                    description='Overdue fine' if random.random() > 0.5 else 'Damage fine'
                )

        self.stdout.write('✓ Fines created')

        # Create sample waiting list / reservations
        for student in random.sample(list(students), min(3, len(students))):
            # 1-2 reservations per student
            num_reservations = random.randint(1, 2)
            unavailable_books = [b for b in books if b.available_copies == 0]
            if unavailable_books:
                for book in random.sample(unavailable_books, min(num_reservations, len(unavailable_books))):
                    if not BookReservation.objects.filter(student=student, book=book).exists():
                        # Get queue position
                        queue_pos = BookReservation.objects.filter(book=book).count() + 1
                        BookReservation.objects.create(
                            student=student,
                            book=book,
                            queue_position=queue_pos,
                            status=random.choice(['pending', 'notified']),
                        )

        self.stdout.write('✓ Reservations created')

        # Create sample announcements
        announcements_data = [
            ('Extended Library Hours', 'Library will remain open until 11 PM during exams.', 'Info'),
            ('Digital Access Maintenance', 'E-journal portal maintenance Saturday 8-10 AM.', 'Scheduled'),
            ('Fine Waiver Window', '50% fine waiver for returns before March 5.', 'Important'),
            ('New Book Arrivals', 'Check out new books in the Data Science section!', 'Info'),
            ('Library Holiday Hours', 'Library closed on national holidays.', 'Important'),
        ]

        for title, content, category in announcements_data:
            Announcement.objects.get_or_create(
                title=title,
                defaults={
                    'content': content,
                    'is_active': True,
                    'created_at': timezone.now() - timedelta(days=random.randint(1, 7)),
                }
            )

        self.stdout.write('✓ Announcements created')

        # Create sample notifications
        for student in students[:3]:  # Only for first 3 students
            # Create 3-5 notifications per student
            for _ in range(random.randint(3, 5)):
                notif_type = random.choice(['due_reminder', 'fine_alert', 'system'])
                book = random.choice(books) if random.random() > 0.5 else None

                Notification.objects.create(
                    student=student,
                    notification_type=notif_type,
                    title=f'Test Notification {random.randint(1, 100)}',
                    message='This is a sample notification for testing.',
                    related_book=book,
                    is_read=random.random() > 0.3,
                    created_at=timezone.now() - timedelta(hours=random.randint(1, 72)),
                )

        self.stdout.write('✓ Notifications created')
        self.stdout.write(self.style.SUCCESS('✓ All data seeding completed successfully!'))
