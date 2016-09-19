Classy Job
==========

A class-based wrapper around [job collection](https://github.com/vsivsi/meteor-job-collection),
a powerful and easy to use job manager for Meteor.

Adding this package to your [Meteor](http://www.meteor.com/) application adds `Job` and `JobsWorker` classes
into the global scope.

Server side only (with `JobsWorker` available on the client side as well).

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

`run` is expected to be blocking and when it returns the job is seen as successfully completed. The return value
is stored in the job's result. If `run` throws an exception, the job is marked as failed and exception is logged.

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

Working with jobs
-----------------

Job classes will be instantiated automatically every time they are ready and their `run`
method will be called.
Inside your `run` method you can call other methods, for example `log` or `progress` to report
on job's progress.

You can use `Job.find(query, fields)` and `Job.findOne(query, fields)` to get instances of jobs from the database.
Resulting objects will be proper instances of your job classes of the correct type for each result object.
If you want only types of a particular class you can limit the query yourself:

```javascript
Job.find({
  type: ExampleJob.type()
});
```

If you need access to any other functionality of job collection not available directly through
existing methods, you can call `getQueueJob` to get underlying job collection's job.
We call job collection's jobs *queue jobs*.

So, for example, to [cancel](https://github.com/vsivsi/meteor-job-collection#jobcanceloptions-callback---anywhere) a
job, you can do:

```javascript
Job.findOne({
  'data.argument': 'foobar'
}).getQueueJob().cancel();
```

You can use `JobsWorker.collection` to access underlying [job collection](https://github.com/vsivsi/meteor-job-collection).
To convert its jobs (queue jobs) to an instance of a class-based job you can use `Job.fromQueueJob(job)`.
