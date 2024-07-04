# frozen_string_literal: true

class YouController < ApplicationController
  def show
    @you_name = session[:you]
  end

  def update
    params.require(:you_name)
    session[:you] = params[:you_name]
    flash[:notice] = "You are now #{session[:you]}"
    redirect_to you_path
  end
end
