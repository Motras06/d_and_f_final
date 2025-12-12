enum AppRole {
  supplier,      // Поставщик
  hall,          // Менеджер зала / магазина
  storage,       // Склад
  admin,         // Администратор (если будет)
}

String appRoleToString(AppRole role) {
  return role.name; // просто 'supplier', 'hall' и т.д. — совпадает с БД
}

AppRole? stringToAppRole(String role) {
  return AppRole.values.firstWhere(
    (e) => e.name == role,
    orElse: () => AppRole.supplier, // fallback
  );
}