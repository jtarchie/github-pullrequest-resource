# Github Pull Request Resource

Tracks pull requests made to a particular github repo. In the spirit of [Travis
CI](https://travis-ci.org/), a status of pending, success, or failure will be
set on the pull request, which must be explicitly defined in your pipeline.

## Deploying to Concourse

You can use the docker image by defining the [resource type](http://concourse.ci/configuring-resource-types.html) in your pipeline YAML.

For example:

```yaml

resource_types:
- name: pull-request
  type: docker-image
  source:
    repository: jtarchie/pr
```

## Source Configuration

* `repo`: *Required.* The repo name on github.
    Example: `jtarchie/pullrequest-resource`

* `access_token`: *Required.* An access token with `repo:status` access is
  required for *public* repos. An access tocken with `repo` access is required for
  *private* repos.

* `uri`: *Optional.* The URI to the github repo. By default, it assumes
  https://github.com/`repo`.

* `base`: *Optional.* When set, will only pull PRs made against a specific branch. The
  default behaviour is any branch.

* `base_url`: *Optional* The base URL for the Concourse deployment, used for
  linking to builds. On newer versions of Concourse ( >= v0.71.0) , the resource will
  automatically sets the URL.

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

* `disable_forks`: *Optional.* If set to `true`, it will filter out pull requests that
  were created via users that forked from your repo.

* `username`: *Optional.* Username for HTTP(S) auth when pulling/pushing.
  This is needed when only HTTP/HTTPS protocol for git is available (which does not support private key auth)
  and auth is required.

* `password`: *Optional.* Password for HTTP(S) auth when pulling/pushing.

* `paths`: *Optional.* If specified (as a list of glob patterns), only changes
  to the specified files will yield new versions from `check`.

* `ignore_paths`: *Optional.* The inverse of `paths`; changes to the specified
  files are ignored.

* `skip_ssl_verification`: *Optional.* Skips git ssl verification by exporting
  `GIT_SSL_NO_VERIFY=true`.

* `master_depth`: *Optional*. Allows for the depth of the master branch 
  to be configured. Default: 1

* `git_config`: *Optional*. If specified as (list of pairs `name` and `value`)
  it will configure git global options, setting each name with each value.

  This can be useful to set options like `credential.helper` or similar.

  See the [`git-config(1)` manual page](https://www.kernel.org/pub/software/scm/git/docs/git-config.html)
  for more information and documentation of existing git options.

## Behavior

### `check`: Check for new pull requests

Concourse resources always iterate over the latest version. This maps well to
semver and git, but not with pull requests. To find the latests pull
requests, `check` queries for all PRs, selects only PRs without `concourse-ci`
status messages, and then only returns the oldest one from list.

To ensure that `check` can iterate over all PRs, you must explicitly define an
`out` for the PR.

### `in`: Clone the repository, at the given pull request ref

Clones the repository to the destination, and locks it down to a given ref. It is important
to specify `version: every`, otherwise you will only ever get the latest PR.

Submodules are initialized and updated recursively, there is no option to to disable that, currently.

There is `git config` information set on the repo about the PR, which can be consumed within your tasks.

For example:

```bash
git config --get pullrequest.url        # returns the URL to the pull request
git config --get pullrequest.branch     # returns the branch name used for the pull request
git config --get pullrequest.id         # returns the ID number of the PR
git config --get pullrequest.basebranch # returns the base branch used for the pull request
```

#### Parameters

* `fetch_merge`: *Optional*. If set to `true`, it will fetch what the result of PR
  would be otherwise it will fetch the origin branch.
  Defaults to `false`.

### `out`: Update the status of a pull request

Set the status message for `concourse-ci` context on specified pull request.

#### Parameters

* `path`: *Required.* The path of the repository to reference the pull request.

* `status`: *Required.* The status of success, failure, error, or pending.
  * [`on_success`](https://concourse.ci/on-success-step.html) and [`on_falure`](https://concourse.ci/on-failure-step.html) triggers may be useful for you when you wanted to reflect build result to the PR (see the example below).

* `context`: *Optional.* The context on the specified pull request
  (defaults to `status`). Any context will be prepended with `concourse-ci`, so
  a context of `unit-tests` will appear as `concourse-ci/unit-tests` on Github.

* `comment`: *Optional.* The file path of the comment message. Comment owner is same with the owner of `access_token`.

** EXPERIMENTAL **

These are experimental features according to [Github documentation](https://developer.github.com/v3/pulls/#merge-a-pull-request-merge-button). 

* `merge.method`: *Optional.* Use this to merge the PR into the target branch of the PR. There are three available merge methods -- `merge`, `squash`, or `rebase`. Please this [doc](https://developer.github.com/changes/2016-09-26-pull-request-merge-api-update/) for more information.

* `merge.commit_msg`: *Optional.* Used with `merge` to set the commit message for the merge. Specify a file path to the merge commit message.

## Example pipeline

Please see this repo's [pipeline](https://github.com/jtarchie/pullrequest-resource/blob/master/.concourse.yml) for a perfect example.

## Tests

Requires `ruby` to be installed.

  ```sh
  gem install bundler
  bundle install
  bundle exec rspec
  ```

