class Fetch 

	attr_accessor :bus_factor, :bus_factor_string, :releases, :refactoring, :prs, :refactoring_created_at, :refactoring_last_push, :stars, :watchers, :forks, :failure

	CONTRIBUTION_THRESHOLD = 0.7
	REFACTORING_THRESHOLD = 5
	STARS_THRESHOLD = 10
	WATCHERS_THRESHOLD = 5
	FORKS_THRESHOLD = 5

	def repo_bus_factor(token, repos)
	 begin
		my_array  = repos.split('/')
		ownerName = my_array[0]
		repoName  = my_array[1]
		
		# GitHub client
		client = Octokit::Client.new(:access_token => token)
		repository = Octokit::Repository.new(:owner => ownerName, :repo => repoName)

		# Cache
		stack = Faraday::RackBuilder.new do |builder|
			builder.use Faraday::HttpCache
			builder.use Octokit::Response::RaiseError
			builder.adapter Faraday.default_adapter
		end
		client.middleware = stack

		# Output
		output = []

		# Info
		puts("1/6 Fetching repository info…")
		repository_info = client.repository(repository)
		puts(repository_info.inspect) #if options.verbose

		# Forks
		#FORKS_THRESHOLD = 5
		if repository_info.forks_count > FORKS_THRESHOLD
			forks_value = "#{repository_info.forks_count} forks."
		else 
			forks_value = "Few forks (#{repository_info.forks_count})."
		end
		output << ['🍴', forks_value]

		# Watchers
		#WATCHERS_THRESHOLD = 5
		if repository_info.subscribers_count > WATCHERS_THRESHOLD
			watchers_value = "#{repository_info.subscribers_count} watchers."
		else 
			watchers_value = "Few watchers (#{repository_info.subscribers_count})."
		end
		output << ['🔭', watchers_value]

		# Stars
		#STARS_THRESHOLD = 10
	    if repository_info.stargazers_count > STARS_THRESHOLD
	        stars_value = "#{repository_info.stargazers_count} stars."
	    else 
	        stars_value = "Few stars (#{repository_info.stargazers_count})."
	    end
	    output << ['🌟', stars_value]

	    # Age
	    created_at = repository_info.created_at
	    last_push = repository_info.pushed_at
	    output << ['🗓',  "Created #{time_ago_in_words(created_at)} ago; last push #{time_ago_in_words(last_push)} ago."]

	    # PRs
		puts("2/6 Fetching open PRs…")
		open_PRs = client.pull_requests(repository, {:per_page => 100})
		puts(open_PRs.inspect) #if options.verbose

		puts("3/6 Fetching closed PRs…")
		closed_PRs = client.pull_requests(repository, {:state => 'closed'})
		puts(closed_PRs.inspect) #if options.verbose

	    total_PRs_count = open_PRs.count + closed_PRs.count
	    if total_PRs_count > 0
	    	ratio = (Float(closed_PRs.count) / total_PRs_count * 100).round(2)
	    	prs_value = "#{total_PRs_count} PRs: #{closed_PRs.count} closed; #{open_PRs.count} opened; #{ratio}% PRs are closed."
	    else 
	    	prs_value = 'No PRs opened yet for this repository.'
	    end
		output << ['🍻', prs_value]

	    # Refactoring
		code_frequency = nil
		helper(API_CALL_RETRY_COUNT, lambda { |c|  
			puts("4/6 Fetching code frequency…")
			code_frequency = client.code_frequency_stats(repository)
		})
		puts(code_frequency.inspect) #if options.verbose

	    deletions = 0
	    additions = 0
	    refactoring = code_frequency.each { |frequency| 
	    	additions += frequency[1]
	    	deletions += frequency[2]
	    }
	    refactoring = (Float(deletions.abs) / Float(additions) * 100).round(2)
	    #REFACTORING_THRESHOLD = 5
	    if refactoring > REFACTORING_THRESHOLD
	    	refactoring_value = "Deletions to additions ratio: #{refactoring}% (#{deletions}/#{additions})."
	    else
			refactoring_value = "Mostly additions, few deletions (#{deletions}/#{additions})."
	    end
		output << ['🛠', refactoring_value]

		# Releases
		puts("5/6 Fetching releases…")
		releases = client.releases(repository)
		puts(releases.inspect) #if options.verbose
		if !releases.empty?
			latest_release = releases.first
			release_name = latest_release.name.nil? || latest_release.name.empty? ? latest_release.tag_name : latest_release.name
			releases_value = "#{releases.count} releases; latest release \"#{release_name}\": #{time_ago_in_words(latest_release.published_at)} ago."
		else
			releases_value = 'No releases.'
		end
		output << ['📦', releases_value]

		# Bus factor
		contributions = nil 
		helper(API_CALL_RETRY_COUNT, lambda { |c|
			puts("6/6 Fetching contribution statistics…")
			contributions = client.contributors_stats(repository)
		})
		puts(contributions.inspect) #if options.verbose
		contributions = contributions.map { |c| c.total }
		min, max = contributions.minmax
		delta = max - min
		#CONTRIBUTION_THRESHOLD = 0.7
		meaningful = contributions.select { |c|  (max - c) < delta * CONTRIBUTION_THRESHOLD }
		total_contributions = contributions.reduce(0) { |t, c|  t + c }
		if meaningful.empty? 
			bus_factor = 100
		else 
			average = contributions.reduce(0) { |a, c| a + Float(c) / total_contributions }
			bus_factor = (average / meaningful.count * 100.0).round(2)
		end
		if bus_factor > 90
			bus_factor_value = "Bus factor: #{bus_factor}%. Most likely one core contributor."
		else 
			bus_factor_value = "Bus factor: #{bus_factor}% (#{meaningful.count} impactful contributors out of #{contributions.count})."
		end
		output << ['🚌', bus_factor_value]

		# Output
		puts("Thank you for you patience 💕\n\n")
	    table = Terminal::Table.new do |t|
	    	t.title = "#{ownerName}/#{repoName}"
			t.style = {:padding_left => 1, :padding_right => 2}
	    	t.rows = output.each_with_index
	    end
	    puts table

	    puts ""
	    puts "Forks: " + forks_value
	    puts "Watchers: " + watchers_value
	    puts "Stars: " + stars_value
	    puts "Prs: " + prs_value
	    puts "Refactoring: " + refactoring.to_s
	    puts "Releases: " + releases.count.to_s
	    puts "Bus_Factor: " + bus_factor.to_s	

	    repository = Repository.new(
	    	repos_url: repos,
	    	bus_factor: bus_factor, 
	    	bus_factor_string: bus_factor_value, 
	    	releases: releases.count, 
	    	refactoring: refactoring, 
	    	prs: prs_value, 
	    	stars: stars_value, 
	    	watchers: watchers_value, 
	    	forks: forks_value
	    )

	    repository.save

		return repository.id
	    rescue Exception => e
	    	@failure = "Something went wrong with the scrape"
		end
		
	end

end