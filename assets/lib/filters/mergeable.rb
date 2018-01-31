module Filters
  class Mergeable 
    def initialize(pull_requests:, input: Input.instance)
      @pull_requests = pull_requests
      @input = input
    end

    def pull_requests
      if @input.source.only_mergeable
        @memoized ||= @pull_requests.delete_if {|x| !x.mergeable? }
      else
        @pull_requests
      end
    end
  end
end
