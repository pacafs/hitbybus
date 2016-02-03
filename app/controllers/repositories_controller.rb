class RepositoriesController < ApplicationController

	before_action :set_auth
	before_action :set_repository, only: [:show]

	def index
	end

	def new
		a = Octokit::Client.new(access_token: "#{params[:token]}", per_page: 200)
		@results = a.repositories
	end

	def create
		@fetch = Fetch.new
		@rep = @fetch.repo_bus_factor(params[:token], params[:repos])
		if @rep.is_a? Integer
			redirect_to repository_path(@rep)
		else
			redirect_to new_repository_path(token: params[:token]), notice: "Something went wrong!!"
		end
	end

	def show
	end


	private

	def set_repository
      @repository = Repository.find(params[:id])
    end

	
	def set_auth
		@auth = session[:omniauth] if session[:omniauth]
	end

end
