# Countdown
This is a mini rack application that uses a redis database to keep countdown
values associated to keys.

## Installation
The usual things for rack applications.

 * rename the `config/app.yml.example` file to `config/app.yml` and edit
 * bundle install
 * rackup (or use passenger with a real web-server as usual)

## Usage
 * setup a countdown for 10 hits:
  ```
  > curl "http://localhost:9292/set?id=mykey,count=10"
  Ok
  ```
 * check
  ```
  > curl "http://localhost:9292/get?id=mykey"
  10
  ```
 * consume the hits:
  ```
  >for i in 0 1 2 3 4 5 6 7 8 9 ; do curl "http://localhost:9292/register?id=mykey" ; done ; echo
  Ok Ok Ok Ok Ok Ok Ok Ok Ok Ok
  ```
 * check again
  ```
  > curl "http://localhost:9292/get?id=mykey"
  0
  ```
 * check again after __expire__ time
  ```
  > curl "http://localhost:9292/get?id=mykey"
  Err: id not found
  ```
