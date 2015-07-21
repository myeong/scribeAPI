class Classification
  include Mongoid::Document

  field :location
  field :task_key,                        type: String
  field :annotation,                      type: Hash
  field :tool_name

  field :started_at
  field :finished_at
  field :user_agent

  belongs_to    :workflow, :foreign_key => "workflow_id"
  belongs_to    :user
  belongs_to    :subject, foreign_key: "subject_id", inverse_of: :classifications
  belongs_to    :child_subject, class_name: "Subject", inverse_of: :parent_classifications

  after_create  :increment_subject_classification_count, :check_for_retirement_by_classification_count
  after_create  :generate_new_subjects
  after_create  :generate_terms

  scope :by_child_subject, -> (id) { where(child_subject_id: id) }
  scope :having_child_subjects, -> { where(:child_subject_id.nin => ['', nil]) }
  scope :not_having_child_subjects, -> { where(:child_subject_id.in => ['', nil]) }

  def generate_new_subjects
    if workflow.generates_subjects
      workflow.create_secondary_subjects(self)
    end
  end

    # AMS: not sure if workflow.generates_subjects_after is the best measure.
    # =>   In addition, we only want to call this for certain subjects (not collect unique.)
    # =>   right now, this mainly applies to workflow.generates_subjects_method == "collect-unique".
  def check_for_retirement_by_classification_count
    # PB: This isn't quite right.. Retires the *parent* subject rather than the subject generated..
    return nil

    workflow = subject.workflow
    if workflow.generates_subjects_method == "collect-unique"
      if subject.classification_count >= workflow.generates_subjects_after
        puts "retiring because clasification count > ..."
        subject.retire!
      end
    end
  end  

  def workflow_task
    workflow.task_by_key task_key
  end

  def generate_terms
    # Just don't even if can't find current task (i.e. completion_assessment task)
    return if workflow_task.nil?

    annotation.each do |(k,v)|

      # Require a min length of 2 to index:
      next if v.nil? || v.size < 2

      tool_config = workflow_task.tool_config_for_field k

      # Is field configured to be indexed for "common" autocomplete?
      index_term = ! tool_config['suggest'].nil? && tool_config['suggest'] == 'common'
      next if ! index_term

      # Front- and back-end expect fields to be identifiable by workflow_id 
      # and an annotation_key built from the task_key and field key
      #   e.g. "enter_building_address:value"
      key = "#{task_key}:#{k}"

      # puts "Term.index_term! #{workflow_id}, #{key}, #{v}"
      Term.index_term! workflow.id, key, v
    end
  end

  def increment_subject_classification_count
    if self.task_key == "completion_assessment_task" && self.annotation["value"] == "complete_subject"
      subject.increment_retire_count_by_one 
    end
    subject.inc classification_count: 1

    # Push user_id onto Subject.user_ids using mongo's fast addToSet feature, which ensures uniqueness
    Subject.where({id: subject.id}).find_and_modify({"$addToSet" => {classifying_user_ids: user_id}})
  end

  def to_s
    ann = annotation.values.select { |v| v.match /[a-zA-Z]/ }.map { |v| "\"#{v}\"" }.join ', '
    ann = ann.truncate 40
    # {! annotation["toolName"].nil? ? " (#{annotation["toolName"]})" : ''}
    "#{workflow.name.capitalize} Classification (#{ann})"
  end

end
