enum AppRole { supplier, hall, storage, admin }

String appRoleToString(AppRole role) {
  return role.name;
}

AppRole? stringToAppRole(String role) {
  return AppRole.values.firstWhere(
    (e) => e.name == role,
    orElse: () => AppRole.supplier,
  );
}
