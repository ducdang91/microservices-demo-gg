FRONT_END_BINARY=frontApp
LOGGER_BINARY=logServiceApp
BROKER_BINARY=brokerApp
AUTH_BINARY=authApp
LISTENER_BINARY=listener
MAIL_BINARY=mailerServiceApp
AUTH_VERSION=1.0.0
BROKER_VERSION=1.0.0
LISTENER_VERSION=1.0.2
MAIL_VERSION=1.0.0
LOGGER_VERSION=1.0.0

## up: starts all containers in the background without forcing build
up:
	@echo "Starting docker images..."
	docker-compose up -d
	@echo "Docker images started!"

## down: stop docker compose
down:
	@echo "Stopping docker images..."
	docker-compose down
	@echo "Docker stopped!"

## build_dockerfiles: builds all dockerfile images
rm_images:
	@echo "Remove latest images..."

build_dockerfiles:
	@echo "Building dockerfiles..."
	docker build . -f accounts.dockerfile -t ducdang91/accounts:sec18
	docker build . -f loans.dockerfile -t ducdang91/loans:sec18
	docker build . -f cards.dockerfile -t ducdang91/cards:sec18
	docker build . -f configserver.dockerfile -t ducdang91/configserver:sec18
	docker build . -f eurekaserver.dockerfile -t ducdang91/eurekaserver:sec18
	docker build . -f gatewayserver.dockerfile -t ducdang91/gatewayserver:sec18

## push_dockerfiles: pushes tagged versions to docker hub
push_dockerfiles:
	docker push ducdang91/accounts:sec18
	docker push ducdang91/loans:sec18
	docker push ducdang91/cards:sec18
	docker push ducdang91/configserver:sec18
	docker push ducdang91/eurekaserver:sec18
	docker push ducdang91/gatewayserver:sec18
	@echo "Done!"

helm_dpd:
	cd ./helm/eazybank-services/accounts && helm dependencies build
	cd ./helm/eazybank-services/cards && helm dependencies build
	cd ./helm/eazybank-services/loans && helm dependencies build
	cd ./helm/eazybank-services/configserver && helm dependencies build
	cd ./helm/eazybank-services/eurekaserver && helm dependencies build
	cd ./helm/eazybank-services/gatewayserver && helm dependencies build
	cd ./helm/eazybank-services/zipkin && helm dependencies build
	
helm_kc_add:
	helm repo add keycloak https://charts.bitnami.com/bitnami
	helm repo add loki https://grafana.github.io/loki/charts
	helm repo add fluent https://fluent.github.io/helm-charts
	helm repo update

helm_kc:
	gcloud container clusters get-credentials cluster-1 --zone us-central1-c --project steel-climber-365907
	kubectl delete -f https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/latest/kubernetes-examples/keycloak.yaml
# 	kubectl delete -f https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/latest/kubernetes-examples/keycloak.yaml
# 	helm install keycloak --set auth.adminPassword=admin keycloak/keycloak

helm_loki:
	kubectl create ns loki
	helm upgrade --install loki --namespace=loki loki/loki  --set fluent-bit.enabled=true,promtail.enabled=false,grafana.enabled=true,prometheus.enabled=true,prometheus.alertmanager.persistentVolume.enabled=true,prometheus.server.persistentVolume.enabled=true
	helm upgrade --install fluent-bit --namespace=loki loki/fluent-bit --set loki.serviceName=loki.loki.svc.cluster.local
	#helm upgrade --install promtail --namespace=loki loki/promtail --set loki.serviceName=loki.loki.svc.cluster.local
# 	kubectl -n loki get pods
# 	kubectl -n loki edit cm/fluent-bit-fluent-bit-loki #loki.loki.svc.cluster.local name loki<-grafana-loki
# 	helm repo add grafana https://grafana.github.io/helm-charts
# 	helm repo update
# http://loki.loki.svc.cluster.local:3100/

helm_rabbitmq:
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm install rabbitmq --set auth.username=admin --set auth.password=admin --set image.tag=latest --set image.repository=rabbitmq bitnami/rabbitmq --wait

helm_mongodb:
	kubectl create ns db
	helm upgrade --install mongodb --namespace=db bitnami/mongodb

helm_dev:
	cd ./helm/environments/dev-env && helm dependencies build
	cd ./helm/environments && helm install dev-deployment dev-env

helm_dev_upd:
	cd ./helm/environments/dev-env && helm dependencies build
	cd ./helm/environments && helm upgrade dev-deployment dev-env

helm_dev_uni:
	helm uninstall dev-deployment

k8s_istio:
	kubectl apply -f ./kubernetes/1-istio-init.yaml
	kubectl apply -f ./kubernetes/2-istio-minikube.yaml

k8s_fleetman:
	kubectl apply -f ./kubernetes/4-label-default-namespace.yaml
	kubectl apply -f ./kubernetes/5-application-no-istio.yaml
	kubectl apply -f ./kubernetes/6-gateway.yaml
	kubectl apply -f ./kubernetes/7-circuit-breaking.yaml
	kubectl apply -f ./kubernetes/8-enforce-mtls-only.yaml
	kubectl apply -f ./kubernetes/9-storage.yaml
	kubectl apply -f ./kubernetes/10-mongo-stack.yaml
	kubectl apply -f ./kubernetes/11-new-workloads-position-simul-tracker.yaml
	kubectl apply -f ./kubernetes/12-new-services-position-simul-tracker.yaml

k8s_demo:
	kubectl create ns demo
	kubectl label namespace demo istio-injection=enabled
	kubectl apply -n demo  -f ./release/kubernetes-manifests.yaml
	kubectl apply -n demo  -f ./release/istio-manifests.yaml

k8s_dlt:
	kubectl delete --all pods --namespace=default
	kubectl delete --all deployments --namespace=default
# 	kubectl delete --all namespace

CLUSTER_NAME=fleetman
PROJECT_ID=steel-climber-365907
ZONE=us-central1-b

gc_fw:
	gcloud container clusters get-credentials ${CLUSTER_NAME} --project=${PROJECT_ID} --zone=${ZONE}
	#gcloud container clusters get-credentials cluster-1 --zone us-central1-c --project steel-climber-365907
	gcloud compute firewall-rules create ducdang91-kiali --allow tcp:31000
	gcloud compute firewall-rules create ducdang91-jaeger --allow tcp:31001
	gcloud compute firewall-rules create ducdang91-grafana --allow tcp:31002
	gcloud compute firewall-rules create ducdang91-prometheus --allow tcp:2020
	gcloud compute firewall-rules create ducdang91-loki --allow tcp:3100

gc_cluster:
	gcloud container clusters create ${CLUSTER_NAME} --project=${PROJECT_ID} --zone=${ZONE} --machine-type=e2-standard-2 --num-nodes=2
# 	gcloud services enable container.googleapis.com --project ${PROJECT_ID}

gc_fleetman: gc_cluster k8s_istio k8s_fleetman

#
gc_demo: gc_cluster k8s_istio k8s_demo

gc_dlt:
	gcloud container clusters delete ${CLUSTER_NAME} --project=${PROJECT_ID} --zone=${ZONE}

gc_dis:
	kubectl config use-context docker-desktop
docker_rm_imgs:
	 docker image prune -a

## front_end_linux: builds linux executable for front end
front_end_linux:
	@echo "Building linux version of front end..."
	cd front-end && go build -o frontEndLinux ./cmd/web
	@echo "Done!"

## swarm_up: starts the swarm
swarm_up:
	@echo "Starting swarm..."
	docker stack deploy -c swarm.yml myapp

## swarm_down: stops the swarm
swarm_down:
	@echo "Stopping swarm..."
	docker stack rm myapp

POSITION_SIMULATOR_BINARY=k8s-fleetman-position-simulator
POSITION_SIMULATOR_VER=0.0.2
POSITION_TRACKER_BINARY=k8s-fleetman-position-tracker
POSITION_TRACKER_VER=0.0.2
FLEETMAN_QUEUE_BINARY=k8s-fleetman-queue
FLEETMAN_QUEUE_VER=0.0.1

build_all: build_pst_sml build_pst_trk
docker_all: docker_pst_sml docker_pst_trk docker_flm_queue push_all

build_pst_sml:
	@echo "Building ${POSITION_SIMULATOR_BINARY} binary.."
	cd ${POSITION_SIMULATOR_BINARY} && mvn clean install -D maven.test.skip=true
	@echo "${POSITION_SIMULATOR_BINARY} binary built!"

docker_pst_sml:
	@echo "Building ${POSITION_SIMULATOR_BINARY} dockerfile."
	cd ${POSITION_SIMULATOR_BINARY} && docker build -t ducdang91/${POSITION_SIMULATOR_BINARY}:${POSITION_SIMULATOR_VER} .

build_pst_trk:
	@echo "Building ${POSITION_TRACKER_BINARY} binary.."
	cd ${POSITION_TRACKER_BINARY} && mvn clean install -D maven.test.skip=true
	@echo "${POSITION_TRACKER_BINARY} binary built!"

docker_pst_trk:
	@echo "Building ${POSITION_TRACKER_BINARY} dockerfile."
	cd ${POSITION_TRACKER_BINARY} && docker build -t ducdang91/${POSITION_TRACKER_BINARY}:${POSITION_TRACKER_VER} .

docker_flm_queue:
	@echo "Building ${FLEETMAN_QUEUE_BINARY} dockerfile."
	cd ${FLEETMAN_QUEUE_BINARY} && docker build -t ducdang91/${FLEETMAN_QUEUE_BINARY}:${FLEETMAN_QUEUE_VER} .

push_all:
	docker push ducdang91/${POSITION_SIMULATOR_BINARY}:${POSITION_SIMULATOR_VER}
	docker push ducdang91/${POSITION_TRACKER_BINARY}:${POSITION_TRACKER_VER}
	docker push ducdang91/${FLEETMAN_QUEUE_BINARY}:${FLEETMAN_QUEUE_VER}

## build_logger: builds the logger binary as a linux executable
build_loans:
	@echo "Building loans binary..."
	cd loans && mvn clean install -D maven.test.skip=true
	@echo "loans binary built!"

## build_broker: builds the broker binary as a linux executable
build_accounts:
	@echo "Building accounts binary..."
	cd accounts && mvn clean install -D maven.test.skip=true
	@echo "accounts binary built!"

## build_listener: builds the listener binary as a linux executable
build_configserver:
	@echo "Building configserver binary..."
	cd configserver && mvn clean install -D maven.test.skip=true
	@echo "configserver binary built!"

## build_mail: builds the mail binary as a linux executable
build_eurekaserver:
	@echo "Building eurekaserver binary..."
	cd eurekaserver && mvn clean install -D maven.test.skip=true
	@echo "eurekaserver binary built!"

build_gatewayserver:
	@echo "Building gatewayserver binary..."
	cd gatewayserver && mvn clean install -D maven.test.skip=true
	@echo "gatewayserver binary built!"


## up_build: stops docker-compose (if running), builds all projects and starts docker compose
up_build: build_auth build_broker build_listener build_logger build_mail
	@echo "Stopping docker images (if running...)"
	docker-compose down
	@echo "Building (when required) and starting docker images..."
	docker-compose up --build -d
	@echo "Docker images built and started!"

## auth: stops authentication-service, removes docker image, builds service, and starts it
auth: build_auth
	@echo "Building authentication-service docker image..."
	- docker-compose stop authentication-service
	- docker-compose rm -f authentication-service
	docker-compose up --build -d authentication-service
	docker-compose start authentication-service
	@echo "authentication-service built and started!"

## broker: stops broker-service, removes docker image, builds service, and starts it
broker: build_broker
	@echo "Building broker-service docker image..."
	- docker-compose stop broker-service
	- docker-compose rm -f broker-service
	docker-compose up --build -d broker-service
	docker-compose start broker-service
	@echo "broker-service rebuilt and started!"

## logger: stops logger-service, removes docker image, builds service, and starts it
logger: build_logger
	@echo "Building logger-service docker image..."
	- docker-compose stop logger-service
	- docker-compose rm -f logger-service
	docker-compose up --build -d logger-service
	docker-compose start logger-service
	@echo "broker-service rebuilt and started!"

## mail: stops mail-service, removes docker image, builds service, and starts it
mail: build_mail
	@echo "Building mail-service docker image..."
	- docker-compose stop mail-service
	- docker-compose rm -f mail-service
	docker-compose up --build -d mail-service
	docker-compose start mail-service
	@echo "mail-service rebuilt and started!"

## listener: stops listener-service, removes docker image, builds service, and starts it
listener: build_listener
	@echo "Building listener-service docker image..."
	- docker-compose stop listener-service
	- docker-compose rm -f listener-service
	docker-compose up --build -d listener-service
	docker-compose start listener-service
	@echo "listener-service rebuilt and started!"

## start: starts the front end
start:
	@echo "Starting front end"
	cd front-end && go build -o ${FRONT_END_BINARY} ./cmd/web
	cd front-end && ./${FRONT_END_BINARY} &

## stop: stop the front end
stop:
	@echo "Stopping front end..."
	@-pkill -SIGTERM -f "./${FRONT_END_BINARY}"
	@echo "Stopped front end!"

## test: runs all tests
test:
	@echo "Testing..."
	go test -v ./...

## clean: runs go clean and deletes binaries
clean:
	@echo "Cleaning..."
	@cd broker-service && rm -f ${BROKER_BINARY}
	@cd broker-service && go clean
	@cd listener-service && rm -f ${LISTENER_BINARY}
	@cd listener-service && go clean
	@cd authentication-service && rm -f ${AUTH_BINARY}
	@cd authentication-service && go clean
	@cd mail-service && rm -f ${MAIL_BINARY}
	@cd mail-service && go clean
	@cd logger-service && rm -f ${LOGGER_BINARY}
	@cd logger-service && go clean
	@cd front-end && go clean
	@cd front-end && rm -f ${FRONT_END_BINARY}
	@echo "Cleaned!"

## help: displays help
help: Makefile
	@echo " Choose a command:"
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'