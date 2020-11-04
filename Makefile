.PHONY: test

test:
	docker run \
		-v /home/olblak/Project/Jenkins-infra/release:/bats \
		-e "ROOT_DIR=/bats" \
		-e "BRANCH_NAME=master" \
		-e "MAVEN_REPOSITORY_URL=https://repo.jenkins-ci.org" \
		-e "MAVEN_REPOSITORY_USERNAME=test"\
		-e "MAVEN_REPOSITORY_PASSWORD=ee"\
		-e "MAVEN_REPOSITORY_SOURCE_NAME=releases"\
		-e "MAVEN_REPOSITORY_TARGET_NAME=sandobx"\
		-e "PROMOTE_STAGING_MAVEN_ARTIFACTS_ARGS=False"\
		bats/bats:latest \
		-t /bats/utils/release.bats
