# hadoop-benchmarks

This repo contains various benchmark scripts for testing [Hadoop](https://hadoop.apache.org/) clusters.

### TeraSort

```bash
# run default terasort 1 tb benchmark
$ HADOOP_USER_NAME=hdfs ./benchmarks/TeraSort/terasuite.sh

# run multiple terasort benchmarks
$ HADOOP_USER_NAME=hdfs ./benchmarks/TeraSort/terasuite.sh 1G 100G 1T

# gather terasort statistics
$ HADOOP_USER_NAME=hdfs ./benchmarks/TeraSort/terastats.sh /benchmarks/TeraSort/*
```

### TestDFSIO

```bash
# run testdfsio benchmark
$ HADOOP_USER_NAME=hdfs ./benchmarks/TestDFSIO/testdfsio.sh
```
