module Shipit
  class MergePullRequestsJob < BackgroundJob
    include BackgroundJob::Unique
    on_duplicate :drop

    def perform(stack)
      pull_requests = stack.pull_requests.to_be_merged.to_a
      pull_requests.each do |pull_request|
        pull_request.refresh!
        pull_request.reject_unless_mergeable!
        if pull_request.closed?
          pull_request.merged_upstream? ? pull_request.complete! : pull_request.cancel!
        end
      end

      return false unless stack.allows_merges?

      pull_requests.select(&:pending?).each do |pull_request|
        pull_request.refresh!
        begin
          pull_request.merge!
        rescue PullRequest::NotReady
          MergePullRequestsJob.set(wait: 10.seconds).perform_later(stack)
          return false
        end
      end
    end
  end
end
