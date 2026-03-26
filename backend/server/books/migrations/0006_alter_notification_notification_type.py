from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("books", "0005_notification_dedupe_key"),
    ]

    operations = [
        migrations.AlterField(
            model_name="notification",
            name="notification_type",
            field=models.CharField(
                choices=[
                    ("announcement", "Announcement"),
                    ("book_issued", "Book Issued"),
                    ("book_returned", "Book Returned"),
                    ("due_reminder", "Due Reminder"),
                    ("overdue_alert", "Overdue Alert"),
                    ("reservation_ready", "Reservation Ready"),
                    ("waiting_list", "Waiting List"),
                    ("fine_alert", "Fine Alert"),
                    ("system", "System Notification"),
                ],
                max_length=30,
            ),
        ),
    ]
