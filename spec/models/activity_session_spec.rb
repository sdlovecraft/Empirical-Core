require 'rails_helper'


describe ActivitySession, :type => :model do

  describe "can behave like an uid class" do

    context "when behaves like uid" do
      it_behaves_like "uid"
    end

  end

  let(:activity_session) {FactoryGirl.build(:activity_session, time_spent: nil)}

  describe "#activity" do

  	context "when there is a direct activity association" do

	  	let(:activity){ FactoryGirl.create(:activity) }
		  let(:activity_session){ FactoryGirl.build(:activity_session,activity_id: activity.id) }

  		it "must return the associated activity" do
  			expect(activity_session.activity).to eq activity
  		end

	end

	context "when there's not an associated activity but there's a classroom activity" do

	    let!(:activity){ FactoryGirl.create(:activity) }
	    let!(:student){ FactoryGirl.create(:student) }
	    let!(:classroom_activity) { FactoryGirl.create(:classroom_activity, activity_id: activity.id, classroom_id: student.classroom.id) }
		  let(:activity_session){   FactoryGirl.build(:activity_session, classroom_activity_id: classroom_activity.id)                     }

  		it "must return the classroom activity" do
  			activity_session.activity_id=nil
  			expect(activity_session.activity).to eq activity_session.classroom_activity.activity
  		end

	end

  end

  describe "#classroom" do
  	it "TODO: must return a valid classroom object"
  end

  describe "#activity_uid=" do

  	let(:activity){ FactoryGirl.create(:activity) }

  	it "must associate activity by uid" do
  		activity_session.activity_id=nil
  		activity_session.activity_uid=activity.uid
  		expect(activity_session.activity_id).to eq activity.id
  	end

  end

  describe "#activity_uid" do

  	it "must return an uid when activity is present" do
  		expect(activity_session.activity_uid).to be_present
  	end

  end

  describe "#completed?" do

  	it "must be true when completed_at is present" do
  		expect(activity_session).to be_completed
  	end

  	it "must be false when copleted_at is not present" do
  		activity_session.completed_at=nil
  		expect(activity_session).to_not be_completed
  	end

  end

  describe "#for_standards_report" do
    include_context 'Topic Progress Report'
    let(:filters) { {} }
    subject { ActivitySession.for_standards_report(teacher, filters)}

    it "must retrieve completed activity sessions representing the best scores for a teacher's students" do
      expect(subject.size).to eq(best_activity_sessions.size)
    end
  end

  describe "#for_standalone_progress_report" do
    include_context 'Topic Progress Report'

    subject { ActivitySession.for_standalone_progress_report(teacher, filters).to_a }

    context 'sorting' do
      before do
        Timecop.freeze
      end

      after do
        Timecop.return
      end

      context 'by default' do
        let(:filters) { {} }
        it 'sorts by completed_at descending' do
          expect(subject.first.completed_at).to be_within(1.second).of fred_first_grade_topic_session.completed_at
        end
      end

      context 'by activity classification' do
        let(:filters) { {sort: {field: 'activity_classification_name', direction: 'asc'} } }
        it 'retrieves results in the appropriate order' do
          # Primary sort by classification name, secondary by student name
          expect(subject.first.user.name).to eq(alice.name)
        end
      end

      context 'by student name' do
        let(:filters) { {sort: {field: 'student_name', direction: 'desc'} } }
        it 'retrieves results in the appropriate order' do
          expect(subject.first.user.name).to eq(zojirushi.name)
        end
      end

      context 'by completion date' do
        let(:filters) { {sort: {field: 'completed_at', direction: 'desc'} } }
        it 'retrieves results in the appropriate order' do
          expect(subject.first.completed_at).to be_within(1.second).of fred_first_grade_topic_session.completed_at
        end
      end

      context 'by activity name' do
        let(:filters) { {sort: {field: 'activity_name', direction: 'asc'} } }
        it 'retrieves results in the appropriate order' do
          expect(subject.first.activity.name).to eq(activity_for_first_grade_topic.name)
        end
      end

      context 'by score' do
        let(:filters) { {sort: {field: 'percentage', direction: 'desc'} } }
        it 'retrieves results in the appropriate order' do
          expect(subject.first.percentage).to eq(best_score_sessions.first.percentage)
        end
      end

      context 'by standard' do
        let(:filters) { {sort: {field: 'standard', direction: 'asc'} } }
        it 'retrieves results in the appropriate order' do
          expect(subject.first.activity.topic.name).to eq(first_grade_topic.name)
        end
      end
    end
  end

  describe "#by_teacher" do
    # This setup is very convoluted... the factories appear to be untrustworthy w/r/t generating extra records
    let!(:current_teacher) { FactoryGirl.create(:teacher) }
    let!(:current_teacher_student) { FactoryGirl.create(:student) }
    let!(:current_teacher_classroom) { FactoryGirl.create(:classroom, teacher: current_teacher, students: [current_teacher_student]) }
    let!(:current_teacher_classroom_activity) { FactoryGirl.create(:classroom_activity_with_activity, classroom: current_teacher_classroom)}
    let!(:other_teacher) { FactoryGirl.create(:teacher) }
    let!(:other_teacher_student) { FactoryGirl.create(:student) }
    let!(:other_teacher_classroom) { FactoryGirl.create(:classroom, teacher: other_teacher, students: [other_teacher_student]) }
    let!(:other_teacher_classroom_activity) { FactoryGirl.create(:classroom_activity_with_activity, classroom: other_teacher_classroom)}

    before do
      # Can't figure out why the setup above creates 2 activity sessions
      ActivitySession.destroy_all
      2.times { FactoryGirl.create(:activity_session, classroom_activity: current_teacher_classroom_activity, user: current_teacher_student) }
      3.times { FactoryGirl.create(:activity_session, classroom_activity: other_teacher_classroom_activity, user: other_teacher_student) }
    end

    it "only retrieves activity sessions for the students who have that teacher" do
      results = ActivitySession.by_teacher(current_teacher)
      expect(results.size).to eq(2)
    end
  end

  #--- legacy methods

  describe "#grade" do

  	it "must be equal to percentage" do
  		expect(activity_session.grade).to eq activity_session.percentage
  	end

  end

  describe "#owner" do

  	it "must be equal to user" do
  		expect(activity_session.owner).to eq activity_session.user
  	end

  end

  describe "#anonymous=" do

  	it "must be equal to temporary" do
  		expect(activity_session.anonymous=true).to eq activity_session.temporary
  	end

  	it "must return temporary" do
  		activity_session.anonymous=true
  		expect(activity_session.anonymous).to eq activity_session.temporary
  	end
  end

  describe "#owned_by?" do

  	let(:user) {FactoryGirl.build(:user)}

  	it "must return true if temporary true" do
  		activity_session.temporary=true
  		expect(activity_session.owned_by? user).to be_truthy
  	end

  	it "must be true if temporary false and user eq owner" do
  		expect(activity_session.owned_by? activity_session.user).to eq true
  	end

  end

  context "when before_create is fired" do

  	describe "#set_state" do

  		it "must set state as unstarted" do
  			activity_session.state=nil
  			activity_session.save!
  			expect(activity_session.state).to eq "unstarted"
  		end

  	end

  end

  context "when before_save is triggered" do

  	describe "#set_completed_at when state = finished" do
      before do
        activity_session.save!
        activity_session.state="finished"
      end

      context "when completed_at is already set" do
        before do
          activity_session.completed_at = 5.minutes.ago
        end

        it "should not change completed at "do
          expect {
            activity_session.save!
          }.to_not change {
            activity_session.reload.completed_at
          }
        end
      end

      context "when time_spent is not set, but started_at and completed_at are" do
        before do
          activity_session.time_spent = nil
          activity_session.started_at = 10.minutes.ago
          activity_session.completed_at = 5.minutes.ago
          activity_session.save!
        end

        it "should update time_spent" do
          expect(activity_session.time_spent).to eq(300)
        end
      end

      context "when time_spent is not set, and either started_at or completed_at is missing" do
        before do
          activity_session.started_at = nil
          activity_session.completed_at = 5.minutes.ago
          activity_session.save!
        end

        it "should not update time_spent" do
          expect(activity_session.time_spent).to be_nil
        end
      end

      context "when completed_at is not already set" do
        before do
          activity_session.completed_at = nil
          activity_session.save!
        end

        it "should update completed_at" do
          expect(activity_session.completed_at).to_not be_nil
        end
      end
  	end

  end

  context "when completed scope" do
  	describe ".completed" do
  		before do
			FactoryGirl.create_list(:activity_session_with_random_completed_date, 5)
  		end
  		it "must locate all the completed items" do
  			expect(ActivitySession.completed.count).to eq 5
  		end

  		it "completed_at must be present" do
  			ActivitySession.completed.each do |item|
  				expect(item.completed_at).to be_present
  			end
  		end

  		it "must order by date desc" do
  			#TODO: This test is not passing cause the ordering is wrong
  			# p completed=ActivitySession.completed
  			# current_date=completed.first.completed_at
  			# completed.each do |item|
  			# 	expect(item.completed_at).to satisfy { |x| p x.to_s+" <= "+current_date.to_s ||x <= current_date  }
  			# 	current_date=item.completed_at
  			# end
  		end
  	end
  end

  context "when incompleted scope" do

  	describe ".incomplete" do

  		before do
			FactoryGirl.create_list(:activity_session_incompleted, 3)
  		end

  		it "must locate all the incompleted items" do
  			expect(ActivitySession.incomplete.count).to eq 3
  		end

  		it "completed_at must be nil" do
  			ActivitySession.incomplete.each do |item|
  				expect(item.completed_at).to be_nil
  			end
  		end

  	end

  end

  describe "can act as ownable" do

    context "when it's an ownable model" do

      it_behaves_like "ownable"
    end

  end

  describe '#determine_if_final_score' do
    let!(:classroom) {FactoryGirl.create(:classroom)}
    let!(:student) {FactoryGirl.create(:student)}
    let!(:activity) {FactoryGirl.create(:activity)}

    let!(:classroom_activity)   {FactoryGirl.create(:classroom_activity, activity: activity, classroom: classroom)}
    let!(:previous_final_score) {FactoryGirl.create(:activity_session, completed_at: Time.now, percentage: 0.9, is_final_score: true, user: student, classroom_activity: classroom_activity, activity: classroom_activity.activity)}

    it 'updates when new activity session has higher percentage ' do
      new_activity_session =  FactoryGirl.create(:activity_session, is_final_score: false, user: student, classroom_activity: classroom_activity, activity: classroom_activity.activity)
      new_activity_session.update_attributes completed_at: Time.now, state: 'finished', percentage: 0.95
      expect([ActivitySession.find(previous_final_score.id).is_final_score, ActivitySession.find(new_activity_session.id).is_final_score]).to eq([false, true])
    end

    it 'doesnt update when new activity session has lower percentage' do
      new_activity_session =  FactoryGirl.create(:activity_session, completed_at: Time.now, state: 'finished', percentage: 0.5, is_final_score: false, user: student, classroom_activity: classroom_activity, activity: classroom_activity.activity)
      expect([ActivitySession.find(previous_final_score.id).is_final_score, ActivitySession.find(new_activity_session.id).is_final_score]).to eq([true, false])
    end

  end

  context 'concept tag methods' do
    let!(:activity_session) { FactoryGirl.create(:activity_session) }
    let(:typing_speed_class) { FactoryGirl.create(:concept_class, name: "Typing Speed") }
    let(:typing_speed_category) { FactoryGirl.create(:concept_category, name: "Typing Speed") }
    let(:typing_speed_tag) { FactoryGirl.create(:concept_tag, name: "Typing Speed", concept_class: typing_speed_class) }
    let(:grammar_concepts_class) { FactoryGirl.create(:concept_class, name: "Grammar Concepts")}
    let(:grammar_category) { FactoryGirl.create(:concept_category, name: "Something grammar")}
    let(:prepositions_tag) { FactoryGirl.create(:concept_tag, name: "Prepositions", concept_class: grammar_concepts_class)}

    describe "#all_concept_class_stats" do
      before do
        activity_session.concept_tag_results.create!(
          concept_tag: typing_speed_tag,
          concept_category: typing_speed_category,
          metadata: {
            wpm: 5
          }
        )
        activity_session.concept_tag_results.create!(
          concept_tag: prepositions_tag,
          concept_category: grammar_category,
          metadata: {
            correct: 1
          }
        )
      end

      it "displays all concept class stats for an activity session" do
        html = activity_session.all_concept_class_stats
        typing_speed_header = "Typing Speed"
        grammar_header = "Grammar Concepts"
        expect(html).to include(typing_speed_header)
        expect(html).to include(grammar_header)
        expect(html).to include(prepositions_tag.name)
      end
    end

    describe "#grammar_concepts_stats" do
      before do
        activity_session.concept_tag_results.create!(
          concept_tag: typing_speed_tag,
          concept_category: typing_speed_category,
          metadata: {
            wpm: 5
          }
        )
        activity_session.concept_tag_results.create!(
          concept_tag: prepositions_tag,
          concept_category: grammar_category,
          metadata: {
            correct: 1
          }
        )
      end

      it "displays a breakdown of the grammar concepts and correct/incorrect" do
        html = activity_session.grammar_concepts_stats(activity_session.concept_tag_results)
        # These expectations are kinda weird because it's a pain to match the html structure
        expect(html).to include(prepositions_tag.name)
        expect(html).to include("1")
        expect(html).to include("0")
      end

      it "should only include tags from the Grammar Concepts class" do
        html = activity_session.grammar_concepts_stats(activity_session.concept_tag_results)
        expect(html).to_not include(typing_speed_tag.name)
      end

      context "when there are badly-formed results" do
        let(:bad_tag) { FactoryGirl.create(:concept_tag, concept_class: grammar_concepts_class) }

        before do
          activity_session.concept_tag_results.create!(
            concept_tag: bad_tag,
            concept_category: grammar_category,
            metadata: {} # Missing a 'correct field'
          )
        end

        it "should not include those results in the counts" do
          html = activity_session.grammar_concepts_stats(activity_session.concept_tag_results)
          expect(html).to_not include(bad_tag.name)
        end
      end
    end

    describe "#typing_speed_stats" do
      before do
        10.times do |i|
          activity_session.concept_tag_results.create!(
            concept_tag: typing_speed_tag,
            concept_category: typing_speed_category,
            metadata: {
              wpm: i
            }
          )
        end
      end

      it "displays a breakdown of average words per minute" do
        average_wpm = 4 # It currently rounds down
        html = activity_session.typing_speed_stats(activity_session.concept_tag_results)
        expect(html).to include('Average words per minute')
        expect(html).to include(average_wpm.to_s)
        # expect(html).to have_tag('div', with: 'Average words per minute')
      end
    end
  end
end