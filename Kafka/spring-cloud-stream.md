#Spring Cloud Stream Kafka Binder

##Polling Properties
```Properties
spring.cloud.stream.kafka.binder.brokers=10.60.156.127:9092
spring.cloud.stream.kafka.binder.auto-create-topics=false
spring.cloud.stream.kafka.binder.consumer-properties.max.poll.records=500
spring.cloud.stream.kafka.binder.consumer-properties.max.poll.interval.ms=300000
spring.cloud.stream.kafka.binder.consumer-properties.key.deserializer=org.apache.kafka.common.serialization.StringDeserializer
spring.cloud.stream.kafka.binder.consumer-properties.value.deserializer=org.apache.kafka.common.serialization.ByteArrayDeserializer
```

* max.poll.records (default: 500) : Consumer will poll max 500 records in one poll
* max.poll.interval.ms (default: 300000 or Integer.MAX_VALUE) : Thời gian delay tối đa giữa 2 lần gọi lệnh poll()

Nếu lệnh poll() tiếp theo được gọi sau `max.poll.interval.ms` thì kafka broker sẽ coi consumer node này die và loại khỏi consumer group

Do đó khi poll về một số records, nhưng không xử lý kịp all records này để consumer thực hiện commit offset và gọi lệnh poll() tiếp theo trong ngưỡng là `max.poll.interval.ms` thì cần cân nhắc giảm `max.poll.records` hoặc tăng `max.poll.interval.ms`

Ở trên là cấu hình mức global, để cấu hình `max.poll.interval.ms` cho từng channel: 
```properties
spring.cloud.stream.kafka.bindings.input_channel_Name.consumer.configuration.max.poll.interval.ms: 5000
```

##Exception Handling
Mặc định, nếu streamListener ném ra (throws) một exception khi xử lý một message, message sẽ được reconsumed và retried 3 lần. Sau đó, message tiếp theo sẽ được xử lý. 
Các cấu hình dưới đây liên quan tới việc retrying:

```yaml
spring:
  cloud:
    stream:
      bindings:
        <input channel Name>:
          consumer:
            # Up to a few attempts, default 3
            maxAttempts: 3
            # Initial backoff interval at retry, unit milliseconds, default 1000
            backOffInitialInterval: 1000
            # Maximum backoff interval, unit milliseconds, default 10000
            backOffMaxInterval: 10000
            # Backoff multiplier, default 2.0
            backOffMultiplier: 2.0
            # Whether to retry when listen throws an exception not listed in retryableExceptions
            defaultRetryable: true
            retryableExceptions:
              java.lang.IllegalStateException: false
```
Với cấu hình trên:
* Tất cả các loại exception sẽ được retry 3 lần trừ  IllegalStateException (`defaultRetryable: true`, `retryableExceptions.java.lang.IllegalStateException: false`)
* backOffInitialInterval, backOffMaxInterval, backOffMultiplier để cấu hình delay time giữa các lần retry

Sau khi đã max retry mà vẫn có exception của message 1, streamListener sẽ bỏ qua message 1 này để xử lý message 2, commit offset will be updated to message 2. Để đưa message 1 vào DLQ (cho phép ứng dụng replay lại các message lỗi nếu cần) thì cấu hình enableDlq:

```yaml
spring.cloud.stream:
  kafka:
    bindings:
      <input channel Name>:
        consumer:
          enableDlq: true
          dlq-producer-properties:
            configuration.key.serializer: org.apache.kafka.common.serialization.StringSerializer
            configuration.value.serializer: org.apache.kafka.common.serialization.ByteArraySerializer
```

##Consumer offset commit
```yaml
spring.cloud.stream:
  kafka:
    bindings:
       <input channel Name>:
        consumer:
          ack-mode: <batch or manual>
```
Spring cloud kafka stream supports two different modes to commit consumer offset. 

* In AsyncMode (ackMode=BATCH, default) KafkaMessageListenerContainer’s will add current consumer record to a acks blockingQueue and batch commit offsets at the beginning of pollAndInvoke loop if accumulated records waiting to ack exceed threshold. this strategy has a performance advantage since it interact less with kafka broker.
* In SyncMode: (ackMode=RECORD) KafkaMessageListenerContainer’s will invoke ackCurrent method immediately after doInvokeOnMessage method, which sends offset to commit to broker after processing of each kafka record.


If set (ackMode=manual), spring cloud stream will add kafka_acknowledgment header in Message; Thông qua đối tượng này để thực hiện manual acknowledge() hoặc nack()

* Sau retry 3 lần, StreamListener vẫn thực hiện commit offset để xử lý message tiếp theo;
```java
    @StreamListener(Processor.INPUT)
    public void receive(Message<String> message) {

        String tpo = String.format("%s-%s@%s",
                message.getHeaders().get(KafkaHeaders.RECEIVED_TOPIC),
                message.getHeaders().get(KafkaHeaders.RECEIVED_PARTITION_ID),
                message.getHeaders().get(KafkaHeaders.OFFSET));
        Acknowledgment acknowledgment = message.getHeaders().get(KafkaHeaders.ACKNOWLEDGMENT, Acknowledgment.class);

        logger.info("[Thread_{}] processing message at: {}", Thread.currentThread().getId(), tpo);

        if (Integer.valueOf(message.getHeaders().get(KafkaHeaders.OFFSET).toString()) % 9 == 0) {
            //Throw exception to simulate Retrying & DLQ
            throw new RuntimeException("Error with message:" + tpo);
        }

        if (acknowledgment != null) {
            acknowledgment.acknowledge(); //manual acknowledgment()
        }
    }
```

* Nắt buộc StreamListener phải xử lý message mà không có exception mới được xử lý message tiếp theo thì ta thực hiện nack() với message đó:

```java
    @StreamListener(Processor.INPUT)
    public void receive(Message<String> message) {

        String tpo = String.format("%s-%s@%s",
                message.getHeaders().get(KafkaHeaders.RECEIVED_TOPIC),
                message.getHeaders().get(KafkaHeaders.RECEIVED_PARTITION_ID),
                message.getHeaders().get(KafkaHeaders.OFFSET));
        Acknowledgment acknowledgment = message.getHeaders().get(KafkaHeaders.ACKNOWLEDGMENT, Acknowledgment.class);

        logger.info("[Thread_{}] processing message at: {}", Thread.currentThread().getId(), tpo);

        if (Integer.valueOf(message.getHeaders().get(KafkaHeaders.OFFSET).toString()) % 9 == 0) {
            //Throw exception to simulate Retrying & DLQ
            //throw new RuntimeException("Error with message:" + tpo);
            if (acknowledgment != null) {
                acknowledgment.nack(Duration.ofSeconds(5));
            }
        }

        if (acknowledgment != null) {
            acknowledgment.acknowledge(); //manual acknowledgment()
        }
    }
```

##Full Example:

Configuration
 ```properties
spring.cloud.stream.kafka.binder.brokers=10.60.156.127:9092
spring.cloud.stream.kafka.binder.auto-create-topics=false
spring.cloud.stream.kafka.binder.consumer-properties.max.poll.records=10
spring.cloud.stream.kafka.binder.consumer-properties.max.poll.interval.ms=300000
spring.cloud.stream.kafka.binder.consumer-properties.key.deserializer=org.apache.kafka.common.serialization.StringDeserializer
spring.cloud.stream.kafka.binder.consumer-properties.value.deserializer=org.apache.kafka.common.serialization.ByteArrayDeserializer

spring.cloud.stream.bindings.ExampleSink.destination=chat-create-ticket-request
spring.cloud.stream.bindings.ExampleSink.group=ticket-server
spring.cloud.stream.bindings.ExampleSink.consumer.max-attempts=3
spring.cloud.stream.bindings.ExampleSink.consumer.retryable-exceptions.java.lang.IllegalStateException=false
spring.cloud.stream.kafka.bindings.ExampleSink.consumer.ack-mode=manual
spring.cloud.stream.kafka.bindings.ExampleSink.consumer.enableDlq=true
spring.cloud.stream.kafka.bindings.ExampleSink.consumer.dlq-producer-properties.configuration.key.serializer=org.apache.kafka.common.serialization.StringSerializer
spring.cloud.stream.kafka.bindings.ExampleSink.consumer.dlq-producer-properties.configuration.value.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
```

Source code
```java
@EnableBinding(ExampleSink.Processor.class)
public class ExampleSink {

    private static final Logger logger = LoggerFactory.getLogger(ExampleSink.class);

    @StreamListener(Processor.INPUT)
    public void receive(Message<String> message) {

        String tpo = String.format("%s-%s@%s",
                message.getHeaders().get(KafkaHeaders.RECEIVED_TOPIC),
                message.getHeaders().get(KafkaHeaders.RECEIVED_PARTITION_ID),
                message.getHeaders().get(KafkaHeaders.OFFSET));
        Acknowledgment acknowledgment = message.getHeaders().get(KafkaHeaders.ACKNOWLEDGMENT, Acknowledgment.class);

        logger.info("[Thread_{}] processing message at: {}", Thread.currentThread().getId(), tpo);

        if (Integer.valueOf(message.getHeaders().get(KafkaHeaders.OFFSET).toString()) % 7 == 0) {
            throw new IllegalStateException("Throw exception to simulate DLQ: " + tpo);
        }

        if (Integer.valueOf(message.getHeaders().get(KafkaHeaders.OFFSET).toString()) % 8 == 0) {
            throw new RuntimeException("Throw exception to simulate DLQ after 3 Retries: " + tpo);
        }

        if (Integer.valueOf(message.getHeaders().get(KafkaHeaders.OFFSET).toString()) % 9 == 0) {
            //Simulate nack, retrying forever for this message
            if (acknowledgment != null) {
                acknowledgment.nack(Duration.ofSeconds(5));
            }
        }

        if (acknowledgment != null) {
            acknowledgment.acknowledge(); //manual acknowledgment()
        }
    }

    interface Processor {
        String INPUT = "ExampleSink";

        @Input(INPUT)
        SubscribableChannel input();
    }
}
```
