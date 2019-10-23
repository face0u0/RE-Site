module V3
  class PostsController < ApplicationController
    require 'time'
    before_action :authenticate!, only: [:good, :create, :update, :destroy, :index]

    # GET /posts
    def index
      lat = params[:latitude].to_f
      lng = params[:longitude].to_f
      delta = params[:delta].to_f
      delta = 0.0001 if delta < 0.000001 || delta > 3

      @posts = Post.where("(latitude > ?) AND (latitude < ?) AND (longitude > ?) AND (longitude < ?)",
                 lat-delta, lat+delta, lng-delta, lng+delta)

      @json_posts = @posts.map do |post|
        public_return = post.public_return_with_user
        public_return[:distance] = distance(lat, lng, post.latitude, post.longitude)
        public_return
      end
      render json: @json_posts.sort_by{|j| j[:distance]}
    end

    def good
      @current_user = current_user
      @post = Post.find(params[:id])
      if @post.add_good(@current_user.id)
        render json: @post.public_return
      end
    end

    # GET /posts/1
    def show
      render json: Post.find(params[:id])
    end

    # POST /posts
    def create
      new_post = post_params
      @current_user = current_user
      new_post[:user_id] = @current_user.id
      @post = Post.new(new_post)
      if @post.save
        render json: @post.public_return,
               status: :created, location: v3_post_url(@post.id)
      else
        render json: @post.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /posts/1
    def update
      set_post
      if @post.user_id == current_user.id
        if @post.update(post_params)
          render json: @post
        else
          render json: @post.errors, status: :unprocessable_entity
        end
      end
    end

    # DELETE /posts/1
    def destroy
      set_post
      if current_user.id == @post.user_id
        @post.destroy
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_post
      @post = Post.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def post_params
      params.require(:post).permit(:body, :url, :longitude, :latitude)
    end

    def distance(lat1, lng1, lat2, lng2)
      x1 = lat1.to_f * Math::PI / 180
      y1 = lng1.to_f * Math::PI / 180
      x2 = lat2.to_f * Math::PI / 180
      y2 = lng2.to_f * Math::PI / 180
      radius = 6378.137
      diff_y = (y1 - y2).abs
      calc1 = Math.cos(x2) * Math.sin(diff_y)
      calc2 = Math.cos(x1) * Math.sin(x2) - Math.sin(x1) * Math.cos(x2) * Math.cos(diff_y)
      numerator = Math.sqrt(calc1 ** 2 + calc2 ** 2)
      denominator = Math.sin(x1) * Math.sin(x2) + Math.cos(x1) * Math.cos(x2) * Math.cos(diff_y)
      degree = Math.atan2(numerator, denominator)
      degree * radius *1000 #to m
    end
  end
end
