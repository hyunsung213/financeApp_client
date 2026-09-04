class MockUser {
  String id;
  String email;
  String name;
  int? salary;
  int? salaryDay;
  Map<String, int>? budgetAllocation;

  MockUser({
    required this.id,
    required this.email,
    required this.name,
    this.salary,
    this.salaryDay,
    this.budgetAllocation,
  });
}

class MockDB {
  static final List<MockUser> users = [
    MockUser(
      id: 'mock-user-1',
      email: 'test@example.com',
      name: '현성',
    ),
  ];

  static final List<Map<String, dynamic>> transactions = [];
}
