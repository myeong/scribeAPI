API            = require './api'

module.exports =
  componentDidMount: ->

    if @props.params.subject_set_id
      @fetchSubject @props.params.subject_set_id,@props.workflow.id
    else
      @fetchSubjects @props.workflow.id, @props.workflow.subject_fetch_limit

  fetchSubject: (subject_set_id, workflow_id)->
    request = API.type("subject_sets").get(subject_set_id, workflow_id: workflow_id)

    @setState
      subjectSet: []
      currentSubjectSet: null

    request.then (subject_set)=>
      console.log("retrived subejct set", subject_set)
      @setState
        subjectSets: [subject_set]
        currentSubjectSet: subject_set

  fetchSubjects: (workflow_id, limit) ->
    console.log 'FETCHING SUBJECTS'
    request = API.type('subject_sets').get
      workflow_id: workflow_id
      limit: limit
      random: true

    request.then (subject_sets)=>    # DEBUG CODE
      @setState
        subjectSets: subject_sets
        currentSubjectSet: subject_sets[0]
        
    # WHY DOES THIS BREAK?
    # request.error (xhr, status, err) =>
    #   console.error "Error loading subjects: ", url, status, err.toString()
