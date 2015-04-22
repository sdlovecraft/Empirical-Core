class Teachers::UnitsController < ApplicationController
  respond_to :json
  before_filter :teacher!

  # Request format for CREATE and UPDATE:
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

  def create
    unit = Unit.create name: unit_params[:name]
    unit.create_new_cas unit_params[:classrooms], unit_params[:activities]
    # activity_sessions in the state of 'unstarted' are automatically created in an after_create callback in the classroom_activity model
    AssignActivityWorker.perform_async(current_user.id) # current_user should be the teacher
    render json: {}
  end

  def update
    unit = Unit.find params[:id]
    unit.update_attributes(name: unit_params[:name]) unless unit.name == unit_params[:name]

    incoming_cs, incoming_as = [unit_params[:classrooms], unit_params[:activities]]
    extant_cas = unit.classroom_activities

    extant_cas_to_be_updated, extant_cas_to_be_removed = split_extant_cas(extant_cas,
                                                                          incoming_cs,
                                                                          incoming_as)
    extant_cas_to_be_removed.map(&:destroy)

    extant_incoming_cs, new_incoming_cs = split_incoming_classrooms(extant_cas, incoming_cs)
    extant_incoming_as, new_incoming_as = split_incoming_activities(extant_cas, incoming_as)

    unit.update_extant_cas(extant_cas_to_be_updated,
                      extant_incoming_cs,
                      extant_incoming_as)

    unit.create_new_cas_for_new_incoming_classrooms new_incoming_cs, incoming_as
    unit.create_new_cas_for_new_incoming_activities new_incoming_as, incoming_cs
    render json: {}
  end

  def index
    render json: (Unit.index_for_activity_planner(current_user))
  end

  def destroy
    (Unit.find params[:id]).destroy
    render json: {}
  end

  private

  def unit_params
    params[:unit][:classrooms].each{|c| c[:student_ids] ||= []} # rails converts empty json arrays into nil, which is undesirable
    params.require(:unit).permit(:name, classrooms: [:id, :all_students, :student_ids => []], activities: [:id, :due_date])
  end

  # USED IN UPDATE :

  def split_incoming_classrooms extant_cas, incoming_cs
    split_incoming extant_cas, incoming_cs, 'classroom_id'
  end

  def split_incoming_activities extant_cas, incoming_as
    split_incoming extant_cas, incoming_as, 'activity_id'
  end

  def split_incoming extant_cas, data, type_id
    extant_ids = extant_cas.pluck(type_id.to_sym)
    split = data.partition do |d|
      extant_ids.include?(d[:id])
    end
    extant_d = split[0]
    new_d = split[1]
    [extant_d, new_d]
  end

  def split_extant_cas extant_cas, incoming_cs, incoming_as
    split_extant_cas = extant_cas.partition do |ca|
      a = incoming_cs.map{|c| c[:id]}.include?(ca.classroom_id)
      b = incoming_as.map{|a| a[:id]}.include?(ca.activity_id)
      a & b
    end
    extant_cas_to_be_updated = split_extant_cas[0]
    extant_cas_to_be_removed = split_extant_cas[1]
    [extant_cas_to_be_updated, extant_cas_to_be_removed]
  end
end