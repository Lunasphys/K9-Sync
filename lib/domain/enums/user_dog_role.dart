/// Role of a user linked to a dog (RGPD / permissions).
/// [value] matches the backend's DogUser.role strings exactly.
enum UserDogRole {
  owner('owner'),
  family('family'),
  dogSitter('dog_sitter');

  final String value;
  const UserDogRole(this.value);
}
