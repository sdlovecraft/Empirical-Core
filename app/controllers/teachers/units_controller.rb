class Teachers::UnitsController < ApplicationController
  respond_to :json
  before_filter :teacher!

  def create

    # create a unit
    unit = Unit.create name: unit_params['name']

    # Request format:
    #   unit: {
    #     name: string
    #     classrooms: [{
    #       id: int
    #       all_students: boolean
    #       student_ids: [int]
    #     }]
    #     activities: [{
    #       id: int
    #       due_date: string
    #     }]
    #   }


    activity_data = unit_params['activities'].values
    classroom_data = unit_params['classrooms'].values
    create_classroom_activities_using_activity_data_and_classroom_data unit, activity_data, classroom_data

    # activity_sessions in the state of 'unstarted' are automatically created in an after_create callback in the classroom_activity model
    AssignActivityWorker.perform_async(current_user.id) # current_user should be the teacher
    render json: {}

  end

  def create_classroom_activities_using_activity_data_and_classroom_data unit, activity_data, classroom_data
    activity_data.each do |ad|
      activity_id = ad['id']
      due_date = ad['due_date']
      classroom_data.each do |cd|
        cd['student_ids'] ||= []
        unit.classroom_activities.create!(activity_id: activity_id,
                                          classroom_id: cd['id'],
                                          assigned_student_ids: (cd['student_ids']),
                                          due_date: due_date)
      end
    end
  end

  def update
    unit = Unit.find params[:id]
    unit.update_attributes(name: unit_params['name']) unless unit.name == unit_params['name']

    classroom_data = unit_params['classrooms'].values

    extant_cas = unit.classroom_activities
    incoming_activity_data = unit_params['activities'].values
    incoming_activity_ids = incoming_activity_data.map{|data| data['id'].to_i}
    split = extant_cas.partition{|ca| incoming_activity_ids.include?(ca.activity_id)}
    to_be_kept    = split[0]
    to_be_removed = split[1]
    to_be_added_activity_data = incoming_activity_data
                                  .reject{|activity_data| extant_cas.map(&:activity_id).include?(activity_data['id'].to_i) }

    # update selection of students for the keepers

    # destroy classroom_activities for classrooms no longer selected

    cids = classroom_data.map{|cd| cd['id'].to_i}
    split2  = to_be_kept.partition{|x| cids.include?(x.classroom_id)}
    cas_to_be_kept = split2[0]
    cas_to_be_removed =split2[1]
    cas_to_be_removed.map(&:destroy)


    function1 cas_to_be_kept, classroom_data

    # destroy those no longer wanted
    to_be_removed.map(&:destroy)

    # add the newly desired
    create_classroom_activities_using_activity_data_and_classroom_data unit, to_be_added_activity_data, classroom_data

    render json: {}
  end

  def function1 cas_to_be_kept, classroom_data
    cas_to_be_kept.group_by(&:classroom_id).each do |classroom_id, cas|
      w1 = classroom_data.find{|cd| cd['id'].to_i == classroom_id}
      new_asi = w1['student_ids'].present? ? w1['student_ids'].map(&:to_i) : []

      previous_asi = cas[0].assigned_student_ids

      return if contain_same_elements(previous_asi, new_asi)

      it_was_everyone = (previous_asi.length == 0)

      if it_was_everyone
        student_ids_to_unassign = (cas[0].classroom.students.map(&:id) - new_asi)
        ClassroomActivity.unassign_students_by_id_from_multiple_classroom_activities cas, student_ids_to_unassign
        ClassroomActivity.mass_update_assigned cas, new_asi
      else
        it_will_not_be_everyone = (new_asi.length != 0)
        if it_will_not_be_everyone
          student_ids_to_unassign     = previous_asi - new_asi
          ClassroomActivity.mass_unassign_students_by_id cas, student_ids_to_unassign
        end
        ClassroomActivity.mass_update_assigned_and_assign cas, new_asi # will only create sessions for the newly added (see method)
      end
    end
  end

  def index
    cas = current_user.classrooms.map(&:classroom_activities).flatten
    units = cas.group_by{|ca| ca.unit_id}
    arr = []
    units.each do |unit_id, classroom_activities|

      x1 = classroom_activities.reject{|ca| ca.due_date.nil?}.compact

      x1 = x1.sort{|a, b| a.due_date <=> b.due_date}

      x1 = x1.map{|ca| (ClassroomActivitySerializer.new(ca)).as_json(root: false)}

      classrooms = x1.map{|ca| ca[:classroom]}.compact.uniq

      assigned_student_ids = []

      classroom_activities.each do |ca|
        if ca.assigned_student_ids.nil? or ca.assigned_student_ids.length == 0
          y = ca.classroom.students.map(&:id)
        else
          y = ca.assigned_student_ids
        end
        assigned_student_ids = assigned_student_ids.concat(y)
      end

      num_students_assigned = assigned_student_ids.uniq.length

      x1 = x1.uniq{|y| y[:activity_id] }

      ele = {unit: Unit.find(unit_id), classroom_activities: x1, num_students_assigned: num_students_assigned, classrooms: classrooms}
      arr.push ele
    end


    render json: arr
  end

  def destroy
    (Unit.find params[:id]).destroy
    render json: {}
  end

  private

  def unit_params
    params.require(:unit).permit(:name, classrooms: [:id, :all_students, :student_ids => []], activities: [:id, :due_date])
  end

  def contain_same_elements arr1, arr2
    arr1.sort.uniq == arr2.sort.uniq
  end
end