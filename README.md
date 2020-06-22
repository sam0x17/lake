# lake
Lake is a generic connection pooling shard for the crystal programming language. With
Lake, you can create a generically typed `Lake(T)` for whatever type of connection
or object you want to work with.

## Overview

When you want to use a connection/object in the pool, simply call `#dip` /
`lake.dip{ |connection| connection.do_stuff }` to asynchronously get a reference
to a free connection in the pool and use it within the block you provide, or call
`#dip_sync` with the same parameters for a synchronous version of `#dip`.

```crystal
lake = Lake(Redis).new
lake.dip { |redis| puts redis.get("my-key") }
lake.dip { |redis| redis.set("mey-key", "cool") }
# no guarantee on run order since `#dip` is asynchronous
```
And using `#dip_sync`...

```crystal
lake = Lake(Redis).new
lake.dip_sync { |redis| redis.set("my-key", "hello") }
val = nil
lake.dip_sync { |redis| val = redis.get("my-key") }
val.should eq "hello"
```

When using things like `redis` where certain connection operations, such as pub/sub,
make the connection unusable for a period of time, you can use `#leak` which will
return and remove a connection from the pool and replace it with a new one safely.

```crystal
lake = Lake(Redis).new
redis = lake.leak
spawn do
  redis.subscribe("my-key") do |on|
  ...
``

 Connections are returned by `dip` and `dip_sync` on a least-recently-used basis, to
 ensure that we are always minimizing the chance that another operation is currently
 in-progress on the returned connection.


Lake maintains a channel for each connection in the pool which it uses to buffer incoming
`dip` and `dip_sync` requests.
