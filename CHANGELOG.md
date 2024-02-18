Changelog
=========

v0.0.3
------
* Fix unexpected result returned.

v0.0.2
------
* Fix ``Invalid value: Not in inclusive range`` bug

v0.0.1
------
* Fork from https://github.com/adamlofts/mysql1_dart version 0.20.0
* Add ``Future<Results> execute(String sql, [Map<String, dynamic>? params])``
* Add ``MySqlConnectionPool``
* Add asMap(Function) on Results