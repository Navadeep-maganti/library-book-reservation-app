from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'books', views.BookViewSet, basename='book')
router.register(r'borrowing', views.IssuedBookViewSet, basename='issued-book')
router.register(r'history', views.BorrowHistoryViewSet, basename='borrow-history')
router.register(r'reservations', views.BookReservationViewSet, basename='reservation')
router.register(r'fines', views.FineViewSet, basename='fine')
router.register(r'notifications', views.NotificationViewSet, basename='notification')
router.register(r'push-devices', views.PushDeviceViewSet, basename='push-device')
router.register(r'announcements', views.AnnouncementViewSet, basename='announcement')
router.register(r'alerts', views.DueAlertsViewSet, basename='alert')
router.register(r'dashboard', views.DashboardViewSet, basename='dashboard')

push_device_create = views.PushDeviceViewSet.as_view({'post': 'create'})
push_device_unregister = views.PushDeviceViewSet.as_view({'post': 'unregister'})

urlpatterns = [
    path('', include(router.urls)),
    path('push-devices', push_device_create, name='push-device-create-compat'),
    path(
        'push-devices/unregister',
        push_device_unregister,
        name='push-device-unregister-compat',
    ),
]
