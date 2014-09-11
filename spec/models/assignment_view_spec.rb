require 'spec_helper'

describe AssignmentView, :type => :model do

  	let!(:activity){ FactoryGirl.create(:activity) }  
  	let!(:student){ FactoryGirl.create(:student) }   	
	let(:assignment_view){ FactoryGirl.create(:assignment_view, activity_id: activity.id, classroom_id: student.classroom.id)}

	describe "#choose_everyone" do 

		context "when there aren't students assigned" do 

			it "must returns true" do 
				expect(assignment_view.choose_everyone).to be_truthy
			end

		end

		context "when there are at least one assigned student" do 

			let(:assignment_view){ FactoryGirl.build(:assignment_view, assigned_student_ids: [student.id])} 

			it "must returns false if" do 
				expect(assignment_view.choose_everyone).to be_falsy
			end
		end
	end

	describe "#assigned_student_ids=" do 

		it "must set the assigned student ids" do 
			expect(assignment_view.assigned_student_ids=[student.id]).to eq [student.id]
		end

	end

	describe "#choose_everyone=" do 

		let(:assignment_view){ FactoryGirl.build(:assignment_view, assigned_student_ids: [student.id])} 

		it "must free assigned_student_ids if 1 as arg" do 

			assignment_view.choose_everyone='1'
			expect(assignment_view.assigned_student_ids).to be_nil

		end

	end

end
