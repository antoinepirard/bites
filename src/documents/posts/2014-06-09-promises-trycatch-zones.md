---
title: Comparing Node.js Promises, Try/Catch, Angular Zone.js and yes, Zone
author: Alex Gorbatchev
layout: post
disqus:
  shortname: promises-trycatch-zones
  url: "http://bites.goodeggs.com/posts/promises-trycatch-zones/"
---

> Reposted with permission by [StrongLoop](http://strongloop.com/). Originally appeared on [April 16, 2014](http://strongloop.com/strongblog/comparing-node-js-promises-trycatch-zone-js-angular/).

# Handling errors in async flow

In the [previous article][1] we've talked about managing async flow and escaping the [callback hell][2].

## The problem

Handling errors in asynchronous flow is pretty straightforward and easy. Handling errors in asynchronous flow in a clean and easy to follow manner - not so much.

<!-- more -->

Lets look at the following code:

```js
    function updateDependencies(packageName, done) {
      findPackage(packageName, function(err, content) {
        if (err) {
          done(err);
        }
        else {
          try {
            package = JSON.parse(content);
          }
          catch (e) {
            done(e);
          }

          findDependencies(package, function(err, dependencies)) {
            if (err) {
              done(err);
            }
            else {
              processDependencies(dependencies, function(err) {
                if (err) {
                  done(err);
                }
                else {
                  done(null, dependencies);
                }
              });
            }
          });
        }
      });
    }
```

We are covering all possible failure cases here using combination of `try/catch` and callback error handling, but boy do we repeat ourselves over and over again. Lets try and rewrite this!

## Error handling using try/catch

``` js
    function updateDependencies(packageName, done) {
      try {
        findPackage(packageName, function(err, content) {
          if (err) throw err;

          findDependencies(JSON.parse(content), function(err, dependencies)) {
            if (err) throw err;

            processDependencies(dependencies, function(err) {
              if (err) throw err;

              done(null, dependencies);
            });
          });
        });
      } catch (e) {
        done(e);
      }
    }
```

Nice! That's much better. However, if we run this now, no errors will be caught. What's going on here?

`try/catch` idiom works very well when you have fully synchronous code, but asynchronous operations render it useless.

The outer `try/catch` block will never catch anything because `findPackage` is asynchronous. The function will begin its course while the outer stack runs through and gets to the last line without any errors.

If an error occurs at some point in the future inside asynchronous `findPackage` - **nothing will be caught**.

<img src="/images/posts/promises-trycatch-zones/catch-fail.gif"/>

Not useful.

## Error handling using promises

In the [previous article][1] we've talked about managing asynchronous flow and escaping the [callback hell][2] with promises. Lets put this promises to work here and rewrite this function.

For the sake of moving forward quicker lets assume we are using [Bluebird][3] promises library and that all our APIs now return promises instead of taking callbacks:

``` js
    function updateDependencies(packageName) {
      return findPackage(packageName)
        .then(JSON.parse)
        .then(findDependencies)
        .then(processDependencies)
        .then(res.send)
        ;
    }
```

Oh wow, that is so much nicer! Right? Right!

But Alex, "we've lost our error handling", you might say. That's right, we don't need to do anything special here to propagate error because we return a promise and there's built in support for error flow. Lets see how error handling might look like with promises:

``` js
    button.addEventListener("click", function() {
      updateDependencies("packageName")
        .then(function(dependencies) {
          output.innerHTML = dependencies.join("\n");
        })
        .catch(function(err) {
          output.innerHTML = "There was an error";
        });
    });
```

Very slick, I'm a fan!

## Error using Zones

Handling rejected promises works really well when we are in full control of the flow. But what happens if some third-party code throws an error during an asynchronous operation? Lets look at another example:

``` js
    function thirdPartyFunction() {
      function fakeXHR() {
        throw new Error("Invalid dependencies");
      }

      setTimeout(fakeXHR, 100);
    }

    function main() {
      button.on("click", function onClick() {
        thirdPartyFunction();
      });
    }

    main();
```

In this case, we wouldn't have a chance to catch and process the error. Generally, the only recourse here is using half baked `window.onerror` that doesn't give you any stack information at all. At least you can log something, right? Not that there's much to log:

    Uncaught Error: Invalid dependencies
        fakeXHR

Up until recently that was pretty much all we had. However, this january [Brian Ford][4] of the [angular.js][5] fame has released [Zone.js][6] which aims to help tackle this.

Basically, [Zone.js][6] **overrides all asynchronous functions in the browser** with custom implementations which allows it to keep track of the context. Dangerous? Yes! But as we say in Soviet Russia, "he who doesn't risk never gets to drink champagne" (or in English "nothing ventured, nothing gained").

Anyways, lets look at how this works. Assuming you have included `zones.js` and `long-stack-trace-zone.js` as per the docs, we just change `main()` call to:

``` js
    zone.fork(Zone.longStackTraceZone).run(main);
```

Refresh, click the button, and now our stack looks like this:

```bash
Error: Invalid dependencies
    at fakeXHR (script.js:7:11)
    at Zone.run (zones.js:41:19)
    at zoneBoundFn (zones.js:27:19)
--- Tue Mar 25 2014 21:20:32 GMT-0700 (PDT) - 106ms ago
Error
    at Function.getStacktraceWithUncaughtError (long-stack-trace-zone.js:24:32)
    at Zone.longStackTraceZone.fork (long-stack-trace-zone.js:70:43)
    at Zone.bind (zones.js:25:21)
    at zone.(anonymous function) (zones.js:61:27)
    at marker (zones.js:66:25)
    at thirdPartyFunction (script.js:10:3)
    at HTMLButtonElement.onClick (script.js:15:5)
    at HTMLButtonElement.x.event.dispatch (jquery.js:5:10006)
    at HTMLButtonElement.y.handle (jquery.js:5:6789)
    at Zone.run (zones.js:41:19)
--- Tue Mar 25 2014 21:20:32 GMT-0700 (PDT) - 1064ms ago
Error
    at getStacktraceWithUncaughtError (long-stack-trace-zone.js:24:32)
    at Function.Zone.getStacktrace (long-stack-trace-zone.js:37:15)
    at Zone.longStackTraceZone.fork (long-stack-trace-zone.js:70:43)
    at Zone.bind (zones.js:25:21)
    at HTMLButtonElement.obj.addEventListener (zones.js:132:37)
    at Object.x.event.add (jquery.js:5:7262)
    at HTMLButtonElement.<anonymous> (jquery.js:5:14336)
    at Function.x.extend.each (jquery.js:4:4575)
    at x.fn.x.each (jquery.js:4:1626)
    at x.fn.extend.on (jquery.js:5:14312)
```

What the what?? Cool! We can now see that the relevant code path started in our `onClick` method and went into `thirdPartyFunction`.

The cool part is, since [Zone.js][6] overrides browser methods, it doesn't matter what libraries you use. It just works.

## Another async flow control project called Zones?

Yep, StrongLoop’s [Bert Belder][10] has been working on a similar idea called “[Zone][11]“ for a few months now. (Not to be confused with the Angular [Zone.js][6] project we've just been discussing, which shares the same name and some technical characteristics. Yeah, it’s a little confusing, but we are actively working with [Brian Ford][12] on how to potentially bring together these two projects for the mutual benefit of the JavaScript and Node communities. Stay tuned!)

## Why a Node-specific Zones project?

Currently, there are a couple of problems that make it really hard to deal with asynchronous control flow in Node that Zones looks to address. Specifically:

* Stack traces are useless when an asynchronous function fails.
* Asynchronous functions are hard to compose into more high-level APIs. Imagine implementing a simple asynchronous API like bar(arg1, arg2, cb) where cb is the error-first callback that the user of the API specifies. To implement this correctly you must take care:
  * to always call the callback
  * don’t call the callback more than once
  * don’t synchronously throw and also call the callback
  * don’t call the callback synchronously
* It is difficult to handle errors that are raised asynchronously. Typically node will crash. If the uses chooses to ignore the error, resources may leak. Zones should make it easy to handle errors and to avoid resource leaks.
* Sometimes there is a need to associate user data to an asynchronous flow. There is currently no way to do this.

Want to learn more about Zones? Stay tuned for more information in the coming weeks. Follow us on [Twitter][8] or subscribe to our [newsletter][9] to make sure you don’t miss the announcements.

## What's next?

* Watch [Brian's presentation][7] from ngconf 2014, it's pretty cool!
* Add [Zone.js][6] to your application.
* Profit!

<img src="/images/posts/promises-trycatch-zones/party.gif"/>

[1]: http://strongloop.com/strongblog/node-js-callback-hell-promises-generators/
[2]: http://callbackhell.com/
[3]: https://github.com/petkaantonov/bluebird
[4]: https://github.com/btford
[5]: http://angularjs.org
[6]: https://github.com/btford/zone.js/
[7]: http://www.youtube.com/watch?v=3IqtmUscE_U
[8]: https://twitter.com/StrongLoop
[9]: http://strongloop.com/newsletter-registration/
[10]: https://github.com/piscisaureus
[11]: https://www.npmjs.org/package/zone
[12]: https://github.com/btford
