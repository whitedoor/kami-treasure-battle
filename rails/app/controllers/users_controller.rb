class UsersController < ApplicationController
  skip_before_action :require_login, only: [ :new, :create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      reset_session
      session[:user_id] = @user.id
      redirect_to root_path, notice: "アカウントを作成しました"
    else
      # 要件: 同じユーザー名は「そのアカウント名は使用済みです」
      if @user.errors.added?(:username, :taken) || @user.errors.full_messages.any? { |m| m.include?("has already been taken") }
        flash.now[:alert] = "そのアカウント名は使用済みです"
      else
        flash.now[:alert] = @user.errors.full_messages.join(" / ")
      end
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation)
  end
end

