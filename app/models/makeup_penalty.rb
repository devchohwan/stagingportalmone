class MakeupPenalty < MakeupBase
  self.table_name = 'penalties'
  
  belongs_to :user, class_name: 'MakeupUser', foreign_key: 'user_id'
end