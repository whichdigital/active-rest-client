# ActiveRestClient (ARC) Contributing Guide

## Introduction

This project was built at Which? Ltd in the UK, but was released as open source in 2014 under the MIT Licence.

We're happy to receive contributions from the community for features and bugfixes and hopefully this guide helps new developers to the project to understand how to get started with the internals of ActiveRestClient.

## Overview

![Component Overview Diagram](https://raw.githubusercontent.com/whichdigital/active-rest-client/master/doc/ActiveRestClient%20Internals.png)

## Components

### Base
The main class in ARC is `ActiveRestClient::Base`.  This includes a number of modules to provide a basic object ready to inherit from to form your own API classes.

**Configuration** includes all of the functionality for class and library level configuration (base_url, verbose logging, request format, etc).

**Mapping** provides the class methods `get`, `post`, `put`, `delete`, etc and it dynamically defines a method with the given name.

**Request Filtering** allows for all/any outbound requests to be altered before transmission.  It maintains a list of filters in a class instance variable and applies each one in the defined order to every request.

**Validation** implements some very basic ActiveRecord-like validations to field values (presence, numericality, length and custom-blocks).

**Caching** adds low level caching functionality to the base class - registering a default cache store and adds the ability to read and write a cached response (which are called from the request).

**Recording** allows for developers to record API responses to a file/database for use when creating mock servers.

### Logger

This is a simple class that either uses a plain text file or Rails' logger if being used within a Rails project.

### Connection Manager/Connection

The principle is that ARC keeps a cached `Connection` to each unique API server and these are kept open using [persistent connections](https://en.wikipedia.org/wiki/HTTP_persistent_connection).  The connection for a given `base_url` is created or retrieved from the pool by the `ConnectionManager`.

### Request

`ActiveRestClient::Base` instantiates a new `ActiveRestClient::Request` object for each request, and it's up to this object to format the request body, make the request, parse the response, etc.

### HeaderList

A `Request` has a list of headers associated, but if the same header is set with different capitalisation (e.g. during a `before_request` filter or in a `proxy`) then it should set the same header, not add a new one.  I believe there is a class called something like Rack::Headers which is supposed to do the same thing, but when I came to implement it, it didn't work for me.  *This is a candidate for removal/replacement*.

### Lazy *

`LazyLoader` is a simple proxy class that takes an `ActiveRestClient::Request` object, has a `method_missing` and `respond_to` pair that when called actually calls `#request` on the request object to make the API call.  This is useful if you want to prepare an API object that doesn't make the call unless it's needed (i.e. like ActiveRecord scopes don't execute if they're used within a cached fragment).

`LazyAssociationLoader` is a completely different beast.  This is used in HAL responses where the association 

### ProxyBase

Proxying functionality allows authors of an API class to change any aspect of the request on the way out and the response on the way in.  It means that you can work with an old code base but interact with a new API, or write your code base to use a new API that isn't available yet and proxy to the old API.

It maintains a mapping of method type and URL (either a string for an exact match, or a regular expression for changeable URLs) and executes the first matching mapping.

The `passthrough` method initially rebuilds the url (if the URL itself has been changed or any parameters have been changed) and then makes the original request with the new URL/body.

### ResultIterator

This acts like a simple `Array` where the JSON response was an array, but it adds in a `parallelise` method for if you need request all the elements of an array (if they're lazy loaded for example) in multiple threads.
