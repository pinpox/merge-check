#! /usr/bin/env nix-shell
#! nix-shell -i ruby -p "ruby.withPackages (ps: with ps; [ octokit ])"

require 'octokit'
require 'optparse'

class GithubClient < Octokit::Client

  def initialize(repo, branch)
    @repo = repo #"pinpox/nixos"
    @target_branch =  branch #"main"
    super()
  end

  def branch_contains_sha?(sha)
    status = compare(@repo, @target_branch,  sha).status
    ['behind', 'identical'].include?(status)
  end

  def pr_included?(pr_num)
    commits = pull_request_commits(@repo, pr_num).map { |c| c.sha }
    commits_included?( commits)
  end

  def commits_included?(commits)
    for c in commits do
      return false unless branch_contains_sha?(c)
    end
    return true
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage:

    merge-check -r 'pinpox/nixos' -b main [ -p <PR number> | -c <sha1,sha2,sha3> ]

  Example:
    merge-check -r 'pinpox/nixos' -b main -p 32
    merge-check -r 'pinpox/nixos' -b main -c 34ab919b0762cc1535d37f7a2444fb0f962990ac,20d519cf5979fa1e65ebd4be5205b7961a71b97b
  "

  # TODO make some of these mandatory and remove later check
  opts.on("-b", "--target-branch=BRANCH", "Target BRANCH to check in") do |b| options[:branch] = b end
  opts.on("-r", "--repository REPO", "Repository REPO to use") do |r| options[:repo] = r end
  opts.on("-p", "--pull-request NUM", "Pull request number to check") do |p| options[:pr_num] = p end
  opts.on("-c", "--commits X,Y,Z", Array, "List of commits (sha) to check") do |c| options[:commits] = c end

end.parse!


# PR and commits are mutually exclusive, but at least one has to be set (XOR)
if !(options[:pr_num].nil? ^ options[:commits].nil?)
  puts "Set exactly one of pr number or the list of commits to check"
  exit(500)
end

if not (options[:repo] and options[:branch])
  puts "Missing repository or branch"
  exit(500)
end

client = GithubClient.new(options[:repo], options[:branch])
if options[:pr_num]
  r= client.pr_included?(options[:pr_num])
  puts "PR is: " + (r ? "OPEN" : "MERGED")
  exit(!r)
end

if options[:commits]
  r = client.commits_included?(options[:commits])
  puts "Commits are: " + (r ? "OPEN" : "MERGED")
  exit(!r)
end

