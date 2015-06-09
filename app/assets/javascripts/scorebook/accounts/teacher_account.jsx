'use strict';
$(function () {
  var ele1 = $('#my-account');
  var ele2 = $('#admin-teacher-account-editor');
  var props;
  var ele;
  if (ele1.length > 0) {
    ele = ele1[0];
    props = {
      userType: 'teacher'
    }
  } else if (ele2.length > 0) {
    ele = ele2[0];
    props = {
      userType: 'admin',
      teacherId: ele2.data('id')
    }
  }

  if ((ele1.length > 0) || (ele2.length > 0)) {
    React.render(React.createElement(EC.TeacherAccount, props), ele);
  }
});

EC.TeacherAccount = React.createClass({
  propTypes: {
    userType: React.PropTypes.string.isRequired,
    teacherId: React.PropTypes.number
  },
  getInitialState: function () {
    return ({
      id: null,
      name: '',
      username: '',
      email: '',
      isSaving: false,
      selectedSchool: null,
      originalSelectedSchool: null,
      schoolOptions: [],
      schoolOptionsDoNotApply: false,
      role: 'teacher',
      password: null,
      passwordConfirmation: null,
      errors: {},
      subscription: {id: null, expiration: '2016-01-01', account_limit: null},
      subscriptionType: 'free'
    });
  },
  componentDidMount: function () {
    var url, data;
    if (this.props.userType == 'admin') {
      url = '/cms/users/' + this.props.teacherId + '/show_json'
    } else {
      url = '/teachers/my_account_data';
    }
    $.ajax({
      url: url,
      success: this.populateData
    });
  },
  populateData: function (data) {
    var school = data.user.schools[0];
    var schoolData;
    if (school == null) {
      schoolData = null;
    } else {
      schoolData = {
        id: school.id,
        text: school.name,
        zipcode: school.zipcode
      };
      this.requestSchools(school.zipcode);
      // couldnt get react to re-render the default value of zipcode based on state change so have to use the below
      $('input.zip-input').val(school.zipcode);
    };
    var subscriptionType, subscription;
    if (data.user.subscriptions.length == 0) {
      subscriptionType = 'free';
      subscription = {
        id: null,
        expiration: '2016-01-01',
        account_limit: null
      }
    } else {
      subscriptionType = 'premium';
      subscription = data.user.subscriptions[0];
    }
    this.setState({
      id: data.user.id,
      name: data.user.name,
      username: data.user.username,
      email: data.user.email,
      role: data.user.role,
      selectedSchool: schoolData,
      originalSelectedSchoolId: schoolData.id,
      subscription: subscription,
      subscriptionType: subscriptionType
    });
  },
  displayHeader: function () {
    var str = this.state.name;
    var str2 = str + "'s Account";
    return str2;
  },
  updateName: function () {
    var x = $(this.refs.name.getDOMNode()).val();
    this.setState({name: x});
  },
  updateUsername: function () {
    var x = $(this.refs.username.getDOMNode()).val();
    this.setState({username: x});
  },
  updateEmail: function () {
    var x = $(this.refs.email.getDOMNode()).val();
    this.setState({email: x});
  },
  determineSaveButtonClass: function () {
    var className;
    if (this.state.isSaving) {
      className = 'button-grey';
    } else {
      className = 'button-green';
    }
    return className;
  },
  clickSave: function () {
    this.setState({isSaving: true});
    var data = {
      name: this.state.name,
      username: this.state.username,
      email: this.state.email,
      role: this.state.role,
      password: this.state.password,
      password_confirmation: this.state.passwordConfirmation,
      school_id: this.state.selectedSchool.id,
      original_selected_school_id: this.state.originalSelectedSchoolId,
      school_options_do_not_apply: this.state.schoolOptionsDoNotApply
    }
    var url;
    if (this.props.userType == 'admin') {
      url = '/cms/users/' + this.state.id;
    } else if (this.props.userType == 'teacher') {
      url = '/teachers/update_my_account';
    }
    $.ajax({
      type: "PUT",
      data: data,
      url: url,
      success: this.uponUpdateAttempt
    });
  },
  uponUpdateAttempt: function (data) {
    this.setState({isSaving: false});
    if (data.errors == null) {
      // name may have been capitalized on back-end
      data.errors = {};
      this.setState({
        name: data.user.name,
      });
      if (this.props.userType == 'admin') {
        this.saveSubscription();
      }
    }
    this.setState({errors: data.errors});
  },

  saveSubscription: function () {
    if (this.state.subscriptionType == 'free') {
      if (this.state.subscription.id != null) {
        this.destroySubscription()
      }
    } else if (this.state.subscriptionType == 'premium') {
      if (this.state.subscription.id == null) {
        this.createSubscription();
      } else {
        this.updateSubscription();
      }
    }
  },
  createSubscription: function () {
    $.ajax({
      type: 'POST',
      url: '/subscriptions',
      data: {user_id: this.state.id, expiration: this.state.subscription.expiration, account_limit: this.state.subscription.account_limit},
      success: this.uponSaveSubscription
    });
  },
  updateSubscription: function () {
    $.ajax({
      type: 'PUT',
      url: '/subscriptions/' + this.state.subscription.id,
      data: {expiration: this.state.subscription.expiration, account_limit: this.state.subscription.account_limit},
      success: this.uponSaveSubscription
    })
  },
  uponSaveSubscription: function (data) {
    this.setState({subscription: data.subscription});
  },
  destroySubscription: function () {
    console.log('going to destroy subscription')
    var that = this;
    $.ajax({
      type: 'DELETE',
      url: '/subscriptions/' + this.state.subscription.id
    }).done(function () {
      var subscription = {
        id: null,
        account_limit: null,
        expiration: null
      }
      that.setState({subscription: subscription});
    });
  },
  updateSubscriptionState: function (subscription) {
    this.setState({subscription: subscription});
  },
  updateSubscriptionType: function (type) {
    this.setState({subscriptionType: type});
  },
  updateSchool: function (school) {
    this.setState({selectedSchool: school});
  },
  requestSchools: function (zip) {
    $.ajax({
      url: '/schools.json',
      data: {zipcode: zip},
      success: this.populateSchools
    });
  },
  populateSchools: function (data) {
    this.setState({schoolOptions: data});
  },
  attemptDeleteAccount: function () {
    var confirmed = confirm('Are you sure you want to delete this account?');
    if (confirmed) {
      $.ajax({
        type: 'DELETE',
        url: '/teachers/delete_my_account',
        data: {id: this.state.id}
      }).done(function () {
         window.location.href="http://quill.org";
      });
    }
  },
  updateSchoolOptionsDoNotApply: function () {
    var x = $(this.refs.schoolOptionsDoNotApply.getDOMNode()).attr('checked');
    var schoolOptionsDoNotApply;

    if (x == 'checked') {
      schoolOptionsDoNotApply = true;
    } else {
      schoolOptionsDoNotApply = false;
    }
    this.setState({schoolOptionsDoNotApply: schoolOptionsDoNotApply});
  },
  determineIfSchoolOptionsDoNotApplyShouldBeChecked: function () {
    var value;
    if (this.state.schoolOptionsDoNotApply) {
      value = 'checked';
    } else {
      value = null;
    }
    return value;
  },
  updatePassword: function () {
    var password = $(this.refs.password.getDOMNode()).val()
    this.setState({password: password});
  },
  updatePasswordConfirmation: function () {
    var passwordConfirmation = $(this.refs.passwordConfirmation.getDOMNode()).val();
    this.setState({passwordConfirmation: passwordConfirmation});
  },
  updateRole: function (role) {
    this.setState({role: role});
  },
  render: function () {
    var selectRole, subscription;
    if (this.props.userType == 'admin') {
      selectRole = <EC.SelectRole role={this.state.role} updateRole={this.updateRole} errors={this.state.errors.role}/>
      subscription = <EC.SelectSubscription subscription={this.state.subscription}
                                            subscriptionType={this.state.subscriptionType}
                                            updateSubscriptionType={this.updateSubscriptionType}
                                            updateSubscriptionState={this.updateSubscriptionState} />
    } else {
      selectRole = null;
      subscription = <EC.StaticDisplaySubscription subscriptionType={this.state.subscriptionType}
                                                   subscription={this.state.subscription} />
    }
    return (
      <div className='container'>
        <div className='row'>
          <div className='col-xs-12'>
            <div className='row'>
              <h3 className='form-header col-xs-12'>
               {this.displayHeader()}
              </h3>
            </div>
            <div className='row'>
              <div className='form-label col-xs-2'>
                Real Name
              </div>
              <div className='col-xs-4'>
                <input ref='name' onChange={this.updateName} value={this.state.name}/>
              </div>
              <div className='col-xs-4 error'>
                {this.state.errors.name}
              </div>
            </div>
            <div className='row'>
              <div className='form-label col-xs-2'>
                Username
              </div>
              <div className='col-xs-4'>
                <input ref='username' onChange={this.updateUsername} value={this.state.username}/>
              </div>
              <div className='col-xs-4 error'>
                {this.state.errors.username}
              </div>
            </div>

            {selectRole}

            <div className='row'>
              <div className='form-label col-xs-2'>
                Email
              </div>
              <div className='col-xs-4'>
                <input ref='email' onChange={this.updateEmail} value={this.state.email}/>
              </div>
              <div className='col-xs-4 error'>
                {this.state.errors.email}
              </div>
            </div>
            <div className='row'>
              <div className='form-label col-xs-2'>
                Password
              </div>
              <div className='col-xs-4'>
                <input type='password' ref='password' onChange={this.updatePassword} placeholder="Input New Password"/>
              </div>
              <div className='col-xs-4 error'>
                {this.state.errors.password}
              </div>
            </div>
            <div className='row'>
              <div className='form-label col-xs-2'>
              </div>
              <div className='col-xs-4'>
                <input type='password' ref='passwordConfirmation' onChange={this.updatePasswordConfirmation} placeholder="Re-Enter New Password"/>
              </div>
              <div className='col-xs-4 error'>
                {this.state.errors.password_confirmation}
              </div>
            </div>
            <EC.SelectSchool errors={this.state.errors.school} selectedSchool={this.state.selectedSchool} schoolOptions={this.state.schoolOptions} requestSchools={this.requestSchools} updateSchool={this.updateSchool} />

            <div className='row school-checkbox'>
              <div className='form-label col-xs-2'>
              </div>
              <div className='col-xs-1 no-pr'>
                <input ref='schoolOptionsDoNotApply' onChange={this.updateSchoolOptionsDoNotApply} type='checkbox' checked={this.determineIfSchoolOptionsDoNotApplyShouldBeChecked()}/>
              </div>
              <div className='col-xs-6 no-pl form-label checkbox-label'>
                My school is not listed or I do not teach in the United States.
              </div>
            </div>

            {subscription}

            <div className='row'>
              <div className='col-xs-2'></div>
              <div className='col-xs-4'>
                <button onClick={this.clickSave} className={this.determineSaveButtonClass()}
                >Save Changes</button>
              </div>
            </div>

            <div className='row'>
              <div className='col-xs-2'></div>
              <div onClick={this.attemptDeleteAccount} className='col-xs-2 delete-account'>
                Delete Account
              </div>
            </div>

          </div>
        </div>
      </div>
    );
  }
});