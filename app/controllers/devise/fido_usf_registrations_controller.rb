class Devise::FidoUsfRegistrationsController < DeviseController
  before_action :authenticate_user!

  def new
    @registration_requests = helpers.u2f.registration_requests
    session[:challenges] = @registration_requests.map(&:challenge)
    key_handles = current_user.fido_usf_devices.map(&:key_handle)
    @sign_requests = helpers.u2f.authentication_requests(key_handles)
    @app_id = helpers.u2f.app_id
    render :new
  end

  # Show a list of all registered devices
  def show
    @devices = current_user.fido_usf_devices.all
    render :show
  end

  def destroy
    begin
      device = current_user.fido_usf_devices.find(params[:id])
      @fade_out_id = device.id
      device.destroy
      @devices = current_user.fido_usf_devices.all
      flash[:success] = I18n.t('fido_usf.flashs.device.removed')
    rescue ActiveRecord::RecordNotFound
    end
    respond_to do |format|
      format.js
      format.html { redirect_to user_fido_usf_registration_url }
    end
  end

  def create
    response = U2F::RegisterResponse.load_from_json(params[:response])
    begin
      reg = helpers.u2f.register!(session[:challenges], response)
      FidoUsf::FidoUsfRegistration.create!(
          user: current_user,
          name: 'Unnamed 1',
          certificate: reg.certificate,
          key_handle: reg.key_handle,
          public_key: reg.public_key,
          counter: reg.counter,
          last_authenticated_at: Time.now)
    rescue U2F::Error => e
      @error_message = "Unable to register: #{e.class.name}"
    ensure
      session.delete(:challenges)
    end

    flash[:success] = I18n.t('fido_usf.flashs.device.registered')
    redirect_to user_fido_usf_registration_path()

  end
end