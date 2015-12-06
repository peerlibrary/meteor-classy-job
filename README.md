Classy Job
==========

A class-based wrapper around [job collection](https://github.com/vsivsi/meteor-job-collection),
a powerful and easy to use job manager for Meteor.

Adding this package to your [Meteor](http://www.meteor.com/) application adds `Job` and `JobsWorker` classes
into the global scope.

Server side only.

Installation
------------

```
meteor add peerlibrary:classy-job
```

Jobs
----

The basic use is to extend `Job` class and implement the `run` method:

```javascript
class ExampleJob extends Job {
  run() {
    this.logInfo("Hello world from: " + this.data.name);
  }
}

ExampleJob.register();
```

Then, when you want to put a new instance of the job into the queue, run:

```javascript
new ExampleJob({name: "Foo"}).enqueue({skipIfExisting: true});
```

Class constructor receives data which is then available to the job when it is run (data is stored
in the database and retrieved on a worker, so it should be EJSON-serializable).

`enqueue` accepts the following options:
* `skipIfExisting`, if true, the job will not be enqueued if a not-completed job already exists
* `skipIncludingCompleted`, if true, together with `skipIfExisting`, the job will not be enqueued if a job already exists, even if completed 
* `depends`, if set it is passed to [job collection's `depends`](https://github.com/vsivsi/meteor-job-collection#jobdependsdependencies---anywhere)
* `priority`, if set it is passed to [job collection's `priority`](https://github.com/vsivsi/meteor-job-collection#jobprioritypriority---anywhere)
* `retry`, if set it is passed to [job collection's `retry`](https://github.com/vsivsi/meteor-job-collection#jobretryoptions---anywhere)
* `repeat`, if set it is passed to [job collection's `repeat`](https://github.com/vsivsi/meteor-job-collection#jobrepeatoptions---anywhere)
* `delay`, if set it is passed to [job collection's `delay`](https://github.com/vsivsi/meteor-job-collection#jobdelaymilliseconds---anywhere)
* `after`, if set it is passed to [job collection's `after`](https://github.com/vsivsi/meteor-job-collection#jobaftertime---anywhere)
* `save`, if set it is passed to [job collection's `save`](https://github.com/vsivsi/meteor-job-collection#jobsaveoptions-callback---anywhere)

When using `skipIfExisting` there is a slight race-condition possible. In the worst case there will be
some duplicate work done. This should not be a problem because jobs ought to be idempotent anyway.

Initialization
--------------

Call `JobsWorker.initialize()` in your app on both client and server to initialize the worker environment and
`JobsWorker.collection` collection.

Possible options for `JobsWorker.initialize` with defaults:

```javascript
JobsWorker.initialize({
  collectionName: 'JobQueue',
  workerInstances: parseInt(process.env.WORKER_INSTANCES || '1'),
  stalledJobCheckInterval: 60 * 1000, // ms
  promoteInterval: 15 * 1000 // ms
});
```

You can use `WORKER_INSTANCES` environment variable or `workerInstances` option to control how many workers are enabled
across all Meteor instances for your app. If set to `0` the current Meteor instance will not run a worker.

Call `JobsWorker.start` on the server to start the worker:

```javascript
Meteor.startup(function () {
  JobsWorker.start()
});
```

`JobsWorker.start` call will not do anything if `workerInstances` is `0`. Alternatively, you can simply do not call
`JobsWorker.start`.

Starting is randomly delayed a bit to distribute the behavior of workers equally inside configured intervals.

Jobs are executed serially inside a given worker, one by one.
