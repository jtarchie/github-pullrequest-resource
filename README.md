# Github Pull Request Resource

Tracks Github pull requests made to a particular Github repo. In the spirit of [Travis
CI](https://travis-ci.org/), a status of pending, success, or failure will be
set on the pull request, which must be explicitly defined in your pipeline.

NOTE: Pull requests are implemented differently between the git repo providers. This
resource only support *GITHUB*.

## Deploying to Concourse

You can use the docker image by defining the [resource type](https://concourse-ci.org/resource-types.html) in your pipeline YAML.

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
  required for *public* repos. An access token with `repo` access is required for
  *private* repos.

* `uri`: *Optional.* The URI to the github repo. By default, it assumes
  https://github.com/`repo`.

* `base`: *Optional.* When set, will only pull PRs made against a specific branch. The
  default behaviour is any branch.

* `base_url`: *Optional* The base URL for the Concourse deployment, used for
  linking to builds. On newer versions of Concourse ( >= v0.71.0) , the resource will
  automatically sets the URL.

  This supports the [build environment](https://concourse-ci.org/implementing-resources.html#resource-metadata)
  variables provided by concourse. For example, `context: $BUILD_JOB_NAME` will set the context to the job name.

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

* `disable_forks`: *Optional*, default false. If set to `true`, it will filter
  out pull requests that were created via users that forked from your repo.

* `only_mergeable`: *Optional*, default false. If set to `true`, it will filter
  out pull requests that are not mergeable.  A pull request is mergeable if it has no merge conflicts.

* `require_review_approval`: *Optional*, default false.  If set to `true`, it will
  filter out pull requests that do not have an Approved review.

* `authorship_restriction`: *Optional*, default false.  If set to `true`, will only
  return PRs created by someone who is a collaborator, repo owner, or organization member.

* `label`: *Optional.* If set to a string it will only return pull requests that have been
marked with that specific label. It is case insensitive.

* `username`: *Optional.* Username for HTTP(S) auth when pulling/pushing.
  This is needed when only HTTP/HTTPS protocol for git is available (which does not support private key auth)
  and auth is required.

* `password`: *Optional.* Password for HTTP(S) auth when pulling/pushing.

* `paths`: *Optional.* If specified (as a list of glob patterns), only changes
  to the specified files will yield new versions from `check`.

* `ignore_paths`: *Optional.* The inverse of `paths`; changes to the specified
  files are ignored.

* `ci_skip`: *Optional.* Filters out PRs that have `[ci skip]` message. Default
   is `false`.

* `skip_ssl_verification`: *Optional.* Skips git ssl verification by exporting
  `GIT_SSL_NO_VERIFY=true` and applying it to the Github API client.

* `git_config`: *Optional*. If specified as (list of pairs `name` and `value`)
  it will configure git global options, setting each name with each value.

  This can be useful to set options like `credential.helper` or similar.

  See the [`git-config(1)` manual page](https://www.kernel.org/pub/software/scm/git/docs/git-config.html)
  for more information and documentation of existing git options.

## Behavior

### `check`: Check for new pull requests

Concourse resources always iterate over the latest version. This maps well to
semver and git, but not with pull requests. This filters all open PRs
sorted by most recently updated.

### `in`: Clone the repository, at the given pull request ref

Clones the repository to the destination, and locks it down to a given ref. It
is important to specify `version: every`, otherwise you will only ever get the
latest PR.

There is `git config` information set on the repo about the PR, which can be consumed within your tasks.

For example:

```bash
git config --get pullrequest.url        # returns the URL to the pull request
git config --get pullrequest.branch     # returns the branch name used for the pull request
git config --get pullrequest.id         # returns the ID number of the PR
git config --get pullrequest.body       # returns the PR body
git config --get pullrequest.basebranch # returns the base branch used for the pull request
git config --get pullrequest.basesha    # returns the commit of the base branch used for the pull request
git config --get pullrequest.userlogin  # returns the github user login for the pull request author
```


#### Additional files populated

 * `.git/id`: the pull request id

 * `.git/url`: the URL for the pull request

 * `.git/branch`: the branch associated with the pull request

 * `.git/base_branch`: the base branch of the pull request

 * `.git/base_sha`: the commit of the base branch of the pull request

 * `.git/userlogin`: the user login of the pull request author

 * `.git/head_sha`: the latest commit hash of the branch associated with the pull request

 * `.git/body`: the body of the pull request.

#### Parameters

* `git.depth`: *Optional.* If a positive integer is given, *shallow* clone the
  repository using the `--depth` option.

* `git.submodules`: *Optional*, default `all`. If `none`, submodules will not be
  fetched. If specified as a list of paths, only the given paths will be
  fetched. If `all`, all submodules are fetched.

* `git.disable_lfs`: *Optional.* If `true`, will not fetch Git LFS files.

* `fetch_merge`: *Optional*, default `false`. If set to `true`, it will fetch
  what the result of PR would be otherwise it will fetch the origin branch.


### `out`: Update the status of a pull request

Set the status message for `concourse-ci` context on specified pull request.

#### Parameters

* `path`: *Required.* The path of the repository to reference the pull request.

* `status`: *Required.* The status of success, failure, error, or pending.
  * [`on_success`](https://concourse-ci.org/on-success-step-hook.html#on_success) and [`on_failure`](https://concourse-ci.org/on-failure-step-hook.html#on_failure) triggers may be useful for you when you wanted to reflect build result to the PR (see the example below).

* `context`: *Optional.* The context on the specified pull request
  (defaults to `status`). Any context will be prepended with `concourse-ci`, so
  a context of `unit-tests` will appear as `concourse-ci/unit-tests` on Github.

  This supports the [build environment](https://concourse-ci.org/implementing-resources.html#resource-metadata)
  variables provided by concourse. For example, `context: $BUILD_JOB_NAME` will set the context to the job name.

* `comment`: *Optional.* The file path of the comment message. Comment owner is same with the owner of `access_token`.

* `merge.method`: *Optional.* Use this to merge the PR into the target branch of the PR. There are three available merge methods -- `merge`, `squash`, or `rebase`. Please this [doc](https://developer.github.com/changes/2016-09-26-pull-request-merge-api-update/) for more information.

* `merge.commit_msg`: *Optional.* Used with `merge` to set the commit message for the merge. Specify a file path to the merge commit message.

* `label`: *Optional.* A label to add to the pull request.

## Example pipeline

Please see this repo's [pipeline](https://github.com/jtarchie/pullrequest-resource/blob/master/.concourse.yml) for a perfect example.

There's also an [example](https://github.com/starkandwayne/concourse-pullrequest-playtime) by @starkandwayne.

## Running the tests

Requires `ruby` to be installed.

  ```sh
  gem install bundler
  bundle install
  bundle exec rspec
  ```

Or with the `Dockerfile`, which runs the tests to see if it can successfully build:

  ```
  docker build .
  ```
