from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("books", "0004_alter_bookreservation_unique_together"),
    ]

    operations = [
        migrations.AddField(
            model_name="notification",
            name="dedupe_key",
            field=models.CharField(blank=True, db_index=True, max_length=255),
        ),
    ]
