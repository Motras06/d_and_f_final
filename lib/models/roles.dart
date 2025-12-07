// roles.dart
// (Updated strings to match DB: storage -> storekeeper, added note for 'user')
enum Role {
  user,
  storage,
  supplier,
}

String roleToString(Role r) {
  return switch (r) {
    Role.user => 'user', // Assume added to DB check
    Role.storage => 'storekeeper',
    Role.supplier => 'supplier',
  };
}

Role? stringToRole(String s) {
  return switch (s) {
    'user' => Role.user,
    'storekeeper' => Role.storage,
    'supplier' => Role.supplier,
    _ => null,
  };
}