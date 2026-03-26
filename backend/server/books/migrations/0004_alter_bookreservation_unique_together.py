from django.db import migrations
import django.db.models


class Migration(migrations.Migration):

    dependencies = [
        ('books', '0003_librarysettings_book_description_book_shelf_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='bookreservation',
            name='status',
            field=django.db.models.CharField(
                choices=[
                    ('pending', 'Pending'),
                    ('notified', 'Notified'),
                    ('expired', 'Expired'),
                    ('cancelled', 'Cancelled'),
                    ('issued', 'Issued'),
                ],
                default='pending',
                max_length=20,
            ),
        ),
        migrations.AlterUniqueTogether(
            name='bookreservation',
            unique_together=set(),
        ),
    ]
