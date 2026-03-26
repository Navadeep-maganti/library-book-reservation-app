from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("books", "0006_alter_notification_notification_type"),
    ]

    operations = [
        migrations.CreateModel(
            name="PushDevice",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("token", models.TextField(unique=True)),
                ("platform", models.CharField(choices=[("android", "Android"), ("ios", "iOS")], max_length=20)),
                ("is_active", models.BooleanField(default=True)),
                ("last_seen_at", models.DateTimeField(auto_now=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("student", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name="push_devices", to="accounts.user")),
            ],
            options={
                "ordering": ["-last_seen_at"],
            },
        ),
    ]
