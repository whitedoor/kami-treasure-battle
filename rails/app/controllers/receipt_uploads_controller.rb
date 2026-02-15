class ReceiptUploadsController < ApplicationController
  def show
    @receipt_upload = current_user.receipt_uploads.find(params[:id])

    respond_to do |format|
      format.html
      format.json do
        render json: {
          ok: true,
          receipt_upload: @receipt_upload.as_json
        }
      end
    end
  end

  def generate_card
    receipt_upload = current_user.receipt_uploads.find(params[:id])
    card = CardGenerator.generate_for_receipt_upload!(receipt_upload)
    redirect_to card_path(card)
  rescue CardGenerator::Error => e
    redirect_to receipt_upload_path(receipt_upload), alert: e.message
  end
end

