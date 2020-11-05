.PHONY: test

test:
	docker run \
		-v /home/olblak/Project/Jenkins-infra/release:/bats \
		-e "ROOT_DIR=/bats" \
		-e "BRANCH_NAME=master" \
		-e "MAVEN_REPOSITORY_URL=mock" \
		-e "MAVEN_REPOSITORY_USERNAME=mock"\
		-e "MAVEN_REPOSITORY_PASSWORD=mock"\
		-e "MAVEN_REPOSITORY_SOURCE_NAME=mock"\
		-e "MAVEN_REPOSITORY_TARGET_NAME=mock"\
		-e "PROMOTE_STAGING_MAVEN_ARTIFACTS_ARGS=False"\
		bats/bats:latest \
		-t /bats/utils/release.bats
