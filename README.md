# lake
Lake is a generic connection pooling shard for the crystal programming language. With
Lake, you can create a generically typed `Lake(T)` for whatever type of connection
or object you want to work with.

## Overview

When you want to use a connection/object in the pool, simply call `#dip` to
asynchronously get a reference to a free connection in the pool and use it within
the block you provide, or call `#dip_sync` with the same parameters for a synchronous
version of `#dip`.

```crystal
lake = Lake(Redis).new
lake.dip { |redis| puts redis.get("my-key") }
lake.dip { |redis| redis.set("my-key", "cool") }
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
```

 Connections are returned by `dip` and `dip_sync` on a least-recently-used basis, to
 ensure that we are always minimizing the chance that another operation is currently
 in-progress on the returned connection.

Lake maintains a channel for each connection in the pool which it uses to buffer incoming
`dip` and `dip_sync` requests.

You can also overload the default constructor which calls `.new` on whatever object you
have decided to use as a pool entry type, as well as specify the size of the lake.

```crystal
lake = Lake(Redis).new(50)
```

The second optional parameter allows you to override the default "factory" (`T.new`) for
newly created pool objects by passing a `->{ }` block returning a `T`.

```crystal
lake = Lake(MyClass).new(25, ->{ MyClass.new("some_arg") })
```

Pool objects are initialized at pool creation time using this block, and a new object
is also initialized each time you call `lake.leak`.

If you do not specify a pool size, the default is `24` (`Lake::DEFAULT_CAPACITY`).

## How it Works
A thread-safe queue (channel) is maintained for each object in the pool. When you pass
a block that takes a pool object to `dip_sync` or `dip`, the block is sent over the
appropriate channel and processed when the pool object is done with any other pending
jobs that were already queued for it specifically. Pool objects are accessed via a
least-recently-used pattern to minimize the chances that you are given a pool object
that is still busy.

An event loop is also created for each pool object. The event loop will run until
the object is taken out of the pool via `leak` or until `clear` is called.
