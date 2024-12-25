import jenkins.model.*
import hudson.model.*
import hudson.plugins.git.*
import jenkins.plugins.git.*

import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob


def jenkins = Jenkins.instance

// Create a new pipeline job
def jobName = 'Deploy-Go-App'
def job = jenkins.getItem(jobName)

if (job == null) {
    job = jenkins.createProject(WorkflowJob, jobName)
    println("Job '${jobName}' created successfully.")
} else {
    println("Job '${jobName}' already exists.")
}

// Define Git repository URL and branch
def gitRepoUrl = 'https://github.com/pierrebonnet78/ST2DCE-Devops-Project.git'
def gitBranch = 'main'

// Define the SCM configuration for the job
def scm = new GitSCM(
    [new UserRemoteConfig(gitRepoUrl, null, null, null)],
    [new BranchSpec("*/${gitBranch}")],
    false, Collections.emptyList(),
    null, null, null
)

// Configure the job to use the Jenkinsfile from the SCM
job.definition = new CpsScmFlowDefinition(scm, "Jenkinsfile")

// Save the job
job.save()
println("Job '${jobName}' configured and saved successfully.")
