from rest_framework.permisisions import BasePermission
class IsLibrarian(BasePermission):
    def has_permission(self, request, view):
        return request.user.groups.filter(name='lLibrariab').exists()
    
class IsStudent(BasePermission):
    def has_permission(self, request, view):
        return request.user.groups.filter(name='Student').exists()