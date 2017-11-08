*** Settings ***

Library		DatabaseLibrary
Library		OperatingSystem
Library		RequestsLibrary
Library		Collections


*** Variables ***

${DBName}	./testing/web/clients.db
${PORT}		5000
${HOST}		localhost


*** Test Cases ***

Test Case
	Step 1: connect to SQLite database
	Step 2: get client with a positive balance
	Step 3: get client's active services
	Step 4: get all available services
	Step 5: get available service which is not active for the client
	Step 6: activate new service for the client
	Step 7: waiting until new service will be active
	Step 8: get client's balance
	Step 9: check the client's balance
    
    
*** Keywords ***


Step 1: connect to SQLite database
    Comment	Connect To Database Using Custom Params sqlite3 database='path_to_dbfile/dbname.db'
    Connect To Database Using Custom Params	sqlite3	database="./${DBName}"


Step 2: get client with a positive balance
	    ${output} =	Query	SELECT clients_client_id, balance FROM balances WHERE balance > 0 LIMIT 1;
		${len_output}=	Get Length	${output}
		
		Run Keyword If   ${len_output} == 1	set_values_to_client_id_balance(${output})
		...	ELSE IF   ${len_output} == 0   create_new_valid_user
		
set_values_to_client_id_balance(${str_values})
	
	${output_list}=	Set Variable	${str_values.strip('[]').strip('()').split(',')}
	${client_id}=	Set Variable	${output_list[0]}
	${init_client_balance}=	Set Variable	${output_list[1]}
	Set Test Variable	${client_id}
	Set Test Variable	${init_client_balance}
	Log	${client_id} ${init_client_balance}
	
create_new_valid_user

	${client_name}=	Set Variable	'Test Testov'
	${client_init_balance}=	Set Variable	5.00
	
	${insert_client}=	Execute SQL String    INSERT INTO clients (client_name) VALUES(${client_name});
	Should Be Equal As Strings    ${insert_client}    None
	
	${insert_balance}=	Execute SQL String    INSERT OR IGNORE INTO balances (balance, clients_client_id) VALUES(${client_init_balance}, (SELECT max(client_id) FROM clients WHERE client_name=${client_name}));
	Should Be Equal As Strings    ${insert_balance}    None
	
	${output} =	Query	SELECT clients_client_id, balance FROM balances WHERE balance=${client_init_balance} AND clients_client_id=(SELECT max(client_id) FROM clients WHERE client_name=${client_name});
	
	${str_output}=	Convert To String	${output}
	set_values_to_client_id_balance(${str_output})
	
			
Step 3: get client's active services

	Create Session  http  http://${HOST}:${PORT}
    &{data}=  Create Dictionary  client_id=${client_id}
    &{headers}=  Create Dictionary  Content-Type=application/json
    ${resp}=  Post Request  http  /client/services  data=${data}  headers=${headers}
    Should Be Equal As Strings  ${resp.status_code}  200
    
    ${CLIENT_SERVICES}=	Set Variable	${resp.json()['items']}
    Set Test Variable	${CLIENT_SERVICES}
    Log	${CLIENT_SERVICES}


Step 4: get all available services

	Create Session  http  http://${HOST}:${PORT}
    &{headers}=  Create Dictionary  Content-Type=application/json
    ${resp}=  Get Request  http  /services  headers=${headers}
    Should Be Equal As Strings  ${resp.status_code}  200
    ${SERVICES}=	Set Variable	${resp.json()['items']}
    Set Test Variable	${SERVICES}
    Log	${SERVICES}
    

Step 5: get available service which is not active for the client

	${new_services}=	Set Variable	${SERVICES}
	@{active_client_services}=	Set Variable	${CLIENT_SERVICES}	
	

	:FOR  ${item}  IN  @{active_client_services}
	\	Remove Values From List	${new_services}	${item}
	
	
	${len_new_services}=	Get Length	${new_services}
	Should Not Be Equal As Integers	${len_new_services}	0	msg="Client uses all available services"	
	${random_index}=	Evaluate	random.randint(0, ${len_new_services}-1)	modules=random

	${id_new_service}=	Set Variable	${new_services[${random_index}]['id']}
	${cost_new_service}=	Set Variable	${new_services[${random_index}]['cost']}
	Set Test Variable	${id_new_service}
	Set Test Variable	${cost_new_service}
	
	Log	${id_new_service}
	Log	${cost_new_service}	
	
	
Step 6: activate new service for the client

	Create Session  http  http://${HOST}:${PORT}
	&{data}=  Create Dictionary  client_id=${client_id}	service_id=${id_new_service}
	&{headers}=  Create Dictionary  Content-Type=application/json
	${resp}=  Post Request  http  /client/add_service  data=${data}  headers=${headers}
    Should Be Equal As Strings  ${resp.status_code}  202


Step 7: waiting until new service will be active

	wait until keyword succeeds	120 seconds	10 second	post_until_succeeds
	
post_until_succeeds

	Create Session  http  http://${HOST}:${PORT}
    &{data}=  Create Dictionary  client_id=${client_id}
    &{headers}=  Create Dictionary  Content-Type=application/json
    ${resp}=  Post Request  http  /client/services  data=${data}  headers=${headers}
    Should Be Equal As Strings  ${resp.status_code}  200
    @{services}=	Set Variable	${resp.json()['items']}
    
    ${id_services}=  Create List
    :FOR  ${item}  IN  @{services}
    \	Append To List    ${id_services}    ${item['id']}

    List Should Contain Value	${id_services}	${id_new_service}		
    
    
Step 8: get client's balance

	${client_balance} =	Query	SELECT balance FROM balances WHERE clients_client_id=${client_id};
	${result_client_balance}=	Set Variable	${client_balance[0][0]}
	Set Test Variable	${result_client_balance}


Step 9: check the client's balance

	${calc_balance}=    Evaluate	${init_client_balance}-${cost_new_service}
	Should Be Equal As Numbers	${calc_balance}	${result_client_balance}	precision=2	msg="Client's balance is not correct, expected balance != result balance"	
	
    
	

	
	
	
    
  
  

