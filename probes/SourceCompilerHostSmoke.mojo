def main():
    var values = List[Int64]()
    values.append(20)
    values.append(22)

    var result: Int64 = 0
    for index in range(len(values)):
        result += values[index]

    assert result == 42
    print("MOJO_IOS_SOURCE_COMPILER_HOST_PASS result=", result, sep="")
