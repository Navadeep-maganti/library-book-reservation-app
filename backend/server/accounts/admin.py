from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    fieldsets = DjangoUserAdmin.fieldsets + (
        ("Role Info", {"fields": ("role", "student_id")}),
    )
    add_fieldsets = DjangoUserAdmin.add_fieldsets + (
        ("Role Info", {"fields": ("role", "student_id")}),
    )
    list_display = (
        "username",
        "email",
        "role",
        "student_id",
        "is_staff",
        "is_active",
    )
