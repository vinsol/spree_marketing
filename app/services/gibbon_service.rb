class GibbonService

  attr_reader :members, :list_uid

  MEMBER_STATUS                   = { unsubscribe: 'unsubscribe', subscribe: 'subscribe' }
  DEFAULT_MEMBER_RETRIEVAL_PARAMS = { params: { 'status': MEMBER_STATUS[:subscribe] } }
  LIST_ATTRIBUTES                 = [:permission_reminder, :email_type_option, :campaign_defaults, :contact]
  BATCH_COUNT                     = 50
  RETRY_COUNT                     = 5
  TIME_DELAY                      = 500
  DEFAULT_LIST_GENERATION_PARAMS  = SpreeMarketing::CONFIG[Rails.env].slice(*LIST_ATTRIBUTES)

  def self.gibbon
    @gibbon ||= Gibbon::Request.new(api_key: SpreeMarketing::CONFIG[:gibbon_api_key]
                                    timeout: SpreeMarketing::CONFIG[:timeout].to_i)
  end

  def initialize(list_uid = nil)
    @list_uid = list_uid
  end

  def generate_list(list_name = '')
    response = gibbon.lists.create(body: { name: list_name }.merge(DEFAULT_LIST_GENERATION_PARAMS))
    @list_uid = response['id'] if response['id'].present?
    response
  end

  def update_list(subscribable_emails = [], unsubscribable_uids = [])
    unsubscribe_members(unsubscribable_uids)
    subscribe_members(subscribable_emails)
  end

  def delete_lists(list_uids = [])
    list_uids.each { |list_uid| gibbon.lists(list_uid).delete }
  end

  def subscribe_members(subscribable_emails = [])
    members_batches = subscribable_emails.in_groups_of(BATCH_COUNT, false)
    members_batches.each do |members_batch|
      response = gibbon.batches.create(body: { operations: member_operations_list_to_generate(members_batch) })
      tail_batch_response(response['batch_id'], @new_members_emails, :subscribe)
    end
    retrieve_members
  end

  def unsubscribe_members(unsubscribable_uids = [])
    members_batches = unsubscribable_uids.in_groups_of(BATCH_COUNT, false)
    members_batches.each do |members_batch|
      response = gibbon.batches.create(body: { operations: member_operations_list_to_unsubscribe(members_batch) })
      tail_batch_response(response['batch_id'], members_batch, :unsubscribe)
    end
  end

  def gibbon
    self.class.gibbon
  end

  private

    def tail_batch_response(batch_id, members_data, title)
      unless check_batch_response(batch_id, RETRY_COUNT)
        raise Gibbon::MailChimpError.new("Failed Batch #{ batch_id } --- #{ response.body }", { title: title, body: members_data })
      end
    end

    def check_batch_response(batch_id, retry_count)
      batch_response = gibbon.batches(batch_id).retrieve

      if batch_response['status'] == 'finished'
        true
      else
        if retry_count > 0
          sleep(TIME_DELAY)
          check_batch_response(batch_id, --retry_count)
        else
          false
        end
      end
    end

    def retrieve_members
      @members = gibbon.lists(@list_uid).members.retrieve(DEFAULT_MEMBER_RETRIEVAL_PARAMS)['members']
    end

    def member_operations_list_to_unsubscribe(unsubscribable_uids = [])
      unsubscribable_uids.select do |uid|
        {
          method: "PATCH",
          path: "lists/#{ @list_uid }/members/#{ uid }",
          body: "{\"status\":\"#{ MEMBER_STATUS[:unsubscribe] }\"}"
        }
      end
    end

    def member_operations_list_to_generate(subscribable_emails = [])
      subscribable_emails.select do |email_address|
        {
          method: "POST",
          path: "lists/#{ @list_uid }/members",
          body: "{\"email_address\": \"#{ email_address }\",\"status\":\"#{ MEMBER_STATUS[:subscribe] }\"}"
        }
      end
    end
end