mysql1_ext
======

A MySQL driver for the Dart programming language. Works on Flutter and on the server.

This library aims to provide an easy to use interface to MySQL. `mysql1_ext` originated
as a fork of the mysql1_dart.

Usage
-----

Connect to the database

```dart
var settings = new ConnectionSettings(
  host: 'localhost',
  port: 3306,
  user: 'bob',
  password: 'wibble',
  db: 'mydb'
);
var conn = await MySqlConnection.connect(settings);
```

Execute a query with parameters:

```dart
var userId = 1;
var results = await conn.query('select name, email from users where id = ?', [userId]);
```

Use the results:

```dart
for (var row in results) {
  print('Name: ${row[0]}, email: ${row[1]}');
});
```

Insert some data

```dart
var result = await conn.query('insert into users (name, email, age) values (?, ?, ?)', ['Bob', 'bob@bob.com', 25]);
```

An insert query's results will be empty, but will have an id if there was an auto-increment column in the table:

```dart
print("New user's id: ${result.insertId}");
```

Execute a query with multiple sets of parameters:

```dart
var results = await query.queryMulti(
    'insert into users (name, email, age) values (?, ?, ?)',
    [['Bob', 'bob@bob.com', 25],
    ['Bill', 'bill@bill.com', 26],
    ['Joe', 'joe@joe.com', 37]]);
```

Update some data:

```dart
await conn.query(
    'update users set age=? where name=?',
    [26, 'Bob']);
```

New Features:
-----------
- Add new function for CRUD operations with parameterize, this function will escape strings to reduce request binding to MySQL database.
```dart
await conn.execute('SELECT * FROM sessions WHERE session_id=:sid LIMIT 1', {'sid':'THIS IS SAMPLE SESSION'});
```

- Add Connection Pool
```dart
var settings = new ConnectionSettings(
  host: 'localhost',
  port: 3306,
  user: 'bob',
  password: 'wibble',
  db: 'mydb'
);
var conn = await MySqlConnectionPool.connect(settings);
```

- Add asMap(Function) on Results

Flutter Web
-----------

This package opens a socket to the database. The web platform does not support sockets and so this package does not work on flutter web.
