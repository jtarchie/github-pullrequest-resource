# Github Pull Request Resource

Tracks pull requests made to a particular github repo. In the spirit of [Travis
CI](https://travis-ci.org/), a status of pending, success, or failure will be
set on the pull request, which much be explicitly defined in your pipeline.

Please checkout our [CI Pipeline](http://ci.passed.fail/pipelines/jtarchie-pullrequest-resource).

## Deploying to Concourse

In your bosh deployment manifest, add to the `groundcrew.additional_resource_types` with the following:

```yaml
- image: docker:///jtarchie/pr
  type: pull-request
```

## Source Configuration

* `repo`: *Required.* The repo name on github.
    Example: `jtarchie/pullrequest-resource`

* `access_token`: *Required.* An access token with `repo:status` access.

* `base_url`: *Optional* The base URL for the Concourse deployment, used for
  linking to builds. If not present, no link is provided on the Github pull
  request.

* `private_key`: *Optional.* Private key to use when pulling/pushing.
    Example:
    ```
    private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEAtCS10/f7W7lkQaSgD/mVeaSOvSF9ql4hf/zfMwfVGgHWjj+W
      <Lots more text>
      DWiJL+OFeg9kawcUL6hQ8JeXPhlImG6RTUffma9+iGQyyBMCGd1l
      -----END RSA PRIVATE KEY-----
    ```
* `api_endpoint`: *Optional.* If the repository is located on a GitHub Enterprise
  instance you need to specify the base api endpoint (e.g. "https://\<hostname\>/api/v3/").

## Behavior

### `check`: Check for new pull requests

New pull requests that have no `concourseci` status messages are pulled in.
Since the nature of Concourse is to always have the latest version, some jiggery
pokery was done to allow iteration of each pull request.

### `in`: Clone the repository, at the given pull request ref

Clones the repository to the destination, and locks it down to a given ref.

Submodules are initialized and updated recursively.


### `out`: Update the status of a pull request

Set the status message for `concourseci` context on specified pull request.

#### Parameters

* `path`: *Required.* The path of the repository to reference the pull request.

* `status`: *Required.* The status of success, failure, error, or pending.

* `context`: *Optional.* The context on the specified pull request (defaults to `concourse-ci`)

## Example pipeline

This is what I am currently using to test this resource on Concourse.

```yaml
resources:
- name: repo
  type: pull-request
  source:
    access_token: acecss_token
    private_key: |
      -----BEGIN RSA PRIVATE KEY-----
      My private key.
      -----END RSA PRIVATE KEY-----
    repo: jtarchie/pullrequest-resource
jobs:
- name: test pull request
  plan:
  - get: repo
    trigger: true
  - put: repo
    params:
      path: repo
      status: pending
  - task: do something with git
    config:
      platform: linux
      image: docker:///concourse/git-resource
      run:
        path: sh
        args:
        - -c
        - cd repo && git --no-pager show
      inputs:
      - name: repo
        path: ""
  - put: repo
    params:
      path: repo
      status: success

```

## Tests

Tests can be run two ways, for local feedback and to see how it will run on the resource container.

1. Local, requires `ruby`

```sh
gem install bundler
bundle install
bundle exec rspec
```
2. Container, requires requires `ruby` and `docker`

```sh
gem install bundler
bundle install
rake test
```
