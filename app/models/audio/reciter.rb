# == Schema Information
#
# Table name: audio.reciter
#
#  reciter_id :integer          not null, primary key
#  path       :text             not null
#  slug       :text             not null
#  english    :text             not null
#  arabic     :text             not null
#

class Audio::Reciter < ActiveRecord::Base
    extend Audio

    self.table_name = 'reciter'
    self.primary_key = 'reciter_id'

    has_many :recitations, class_name: 'Audio::Recitation', foreign_key: 'reciter_id'
end
