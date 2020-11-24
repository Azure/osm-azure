available=false
max_retries=${MAX_RETRIES:-60}
sleep_seconds=${SLEEP_SECONDS:-10}
for ((i = 0; i < ${max_retries}; i++))
do
  if [[ ! $(kubectl wait --for=condition=available ${RESOURCE} --all --namespace ${NAMESPACE}) ]]; then
    sleep ${sleep_seconds}
  else
    available=true
    break
  fi
done
if [ "${available}" == true ]; then
  echo "${RESOURCE} is available in namespace - ${NAMESPACE}"
  exit 0
else
  echo "${RESOURCE} is not avilable in namespace - ${NAMESPACE}"
  exit 1
fi