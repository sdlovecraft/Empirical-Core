class Unit < ActiveRecord::Base

  belongs_to :classroom
  has_many :classroom_activities, dependent: :destroy
  has_many :activities, through: :classroom_activities
  has_many :topics, through: :activities

  def self.for_standards_progress_report(teacher, filters)
    with(best_activity_sessions: ActivitySession.for_standards_report(teacher, filters))
      .select("units.id as id, units.name as name")
      .joins('JOIN classroom_activities ON classroom_activities.unit_id = units.id')
      .joins('JOIN best_activity_sessions ON best_activity_sessions.classroom_activity_id = classroom_activities.id')
      .group('units.id')
      .order("units.created_at asc, units.name asc") # Try order by creation date, fall back to name)
  end

  # called in UnitsController#index
  def self.index_for_activity_planner(teacher)
    cas = teacher.classrooms.map(&:classroom_activities).flatten
    units = cas.group_by{|ca| ca.unit_id}
    arr = units.map do |unit_id, classroom_activities|

      x1 = classroom_activities
              .reject{|ca| ca.due_date.nil?}
              .compact
              .sort{|a, b| a.due_date <=> b.due_date}
              .map{|ca| (ClassroomActivitySerializer.new(ca)).as_json(root: false)}

      classrooms = x1.map{|ca| ca[:classroom]}.compact.uniq

      assigned_student_ids = []

      classroom_activities.each do |ca|
        if ca.assigned_student_ids.nil? or ca.assigned_student_ids.empty?
          y = ca.classroom.students.map(&:id)
        else
          y = ca.assigned_student_ids
        end
        assigned_student_ids = assigned_student_ids.concat(y)
      end

      num_students_assigned = assigned_student_ids.uniq.length

      x1 = x1.uniq{|y| y[:activity_id] }

      ele = {unit: Unit.find(unit_id), classroom_activities: x1, num_students_assigned: num_students_assigned, classrooms: classrooms}
      ele
    end
  end

  # CREATING
  # these are called in #create and #update in UnitsController

  def create_new_cas_for_new_incoming_classrooms new_incoming_cs, incoming_as
    create_new_cas new_incoming_cs, incoming_as
  end

  def create_new_cas_for_new_incoming_activities new_incoming_as, incoming_cs
    create_new_cas incoming_cs, new_incoming_as
  end

  def create_new_cas cs, as
    cs.each do |c|
      as.each do |a|
        self.classroom_activities.create(classroom_id: c[:id],
                                         activity_id: a[:id],
                                         assigned_student_ids: c[:student_ids],
                                         due_date: a[:due_date])

      end
    end
  end


  # UPDATING

  def update_extant_cas (extant_cas_to_be_updated,
                         extant_incoming_classrooms,
                         extant_incoming_activities)
    extant_cas_to_be_updated.each{|ca| update_extant_ca(ca, extant_incoming_classrooms, extant_incoming_activities)}
  end

  def update_extant_ca (extant_ca,
                        extant_incoming_classrooms,
                        extant_incoming_activities)

    relevant_incoming_classroom = extant_incoming_classrooms.find{|c| c[:id] == extant_ca.classroom_id}
    relevant_incoming_activity  = extant_incoming_activities.find{|a| a[:id] == extant_ca.activity_id}

    changed_due_date = (extant_ca.due_date.to_date != relevant_incoming_activity[:due_date].to_date)

    are_assigned_students_changed = not_contain_same_elements((extant_ca.assigned_student_ids ||= []), relevant_incoming_classroom[:student_ids])


    if are_assigned_students_changed
      # make sure this is done before we update assigned_student_ids on ca,
      # so we still know who was previously assigned
      update_relevant_activity_sessions extant_ca, relevant_incoming_classroom
    end

    if changed_due_date or are_assigned_students_changed
      extant_ca.update_attributes(due_date: relevant_incoming_activity[:due_date],
                                  assigned_student_ids: relevant_incoming_classroom[:student_ids])
    end
  end

  def not_contain_same_elements arr1, arr2
    arr1.sort.uniq != arr2.sort.uniq
  end

  def update_relevant_activity_sessions extant_ca, relevant_incoming_classroom
    # destroy the activity_sessions of those students who are no longer selected
    # create new activity_sessions for those who are newly selected
    formerly  = get_assigned_student_ids extant_ca, extant_ca.assigned_student_ids
    should_be = get_assigned_student_ids extant_ca, relevant_incoming_classroom[:student_ids]

    extant_sids_to_be_removed = formerly  - should_be
    new_sids_to_be_added      = should_be - formerly

    extant_ca.activity_sessions.where(user_id: extant_sids_to_be_removed).destroy_all
    new_sids_to_be_added.each{|sid| extant_ca.session_for_by_id(sid)}
  end

  def get_assigned_student_ids ca, ids
    (ids.nil? or ids.empty?) ?  ca.classroom.students.pluck(:id) : ids
  end

end
